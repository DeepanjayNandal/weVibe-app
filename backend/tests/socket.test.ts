import { createServer, Server as HttpServer } from 'http';
import { io as ioClient, Socket as ClientSocket } from 'socket.io-client';
import { SocketServer } from '../src/websocket/socket-server';
import { PrismaClient, enum_meet_gender } from '@prisma/client';
import request from 'supertest';
import { createApp } from '../src/app';
import { prisma as appPrisma } from '../src/db/prisma-client';
import { socketServer as contractSocketServer } from '../src/websocket/socket-server';

const prisma = new PrismaClient();
const app = createApp();

const envelope = <T>(data: T) => ({ v: 1 as const, data });

type TestUserSetup = {
  token: string;
  birthDate: string;
  gender: string;
  searchGender: enum_meet_gender;
  latitude: number;
  longitude: number;
};

async function registerUser(token: string): Promise<void> {
  await request(app).post('/api/v1/auth/register').send({ provider: 'google', idToken: token });
}

async function setupUser(config: TestUserSetup): Promise<void> {
  await registerUser(config.token);

  const uid = config.token.split(':')[2];
  const user = await prisma.users.findUnique({ where: { firebase_uid: uid } });
  if (!user) {
    throw new Error('User not found after registration');
  }

  await prisma.users.update({
    where: { id: user.id },
    data: {
      search_gender: config.searchGender,
      search_age_min: 18,
      search_age_max: 35,
      search_radius_km: 50,
      current_status: 'active',
    },
  });

  await prisma.profiles.upsert({
    where: { user_id: user.id },
    update: {
      display_name: uid,
      birth_date: new Date(config.birthDate),
      gender: config.gender,
      personality_primary: 'A',
    },
    create: {
      user_id: user.id,
      display_name: uid,
      birth_date: new Date(config.birthDate),
      gender: config.gender,
      personality_primary: 'A',
    },
  });

  await prisma.$executeRaw`
    UPDATE profiles
    SET location_point = ST_SetSRID(ST_MakePoint(${config.longitude}, ${config.latitude}), 4326)::geography
    WHERE user_id = ${user.id}::uuid
  `;
}

describe('Socket.io Server - Unit Tests', () => {
  let socketServer: SocketServer;
  let httpServer: HttpServer;
  let clientSocketA: ClientSocket;
  let clientSocketB: ClientSocket;
  let port: number;

  const MOCK_TOKEN_A = 'mock:google:socket-unit-a:socket-unit-a@test.com';
  const MOCK_TOKEN_B = 'mock:google:socket-unit-b:socket-unit-b@test.com';

  let userIdA: string;
  let userIdB: string;

  beforeAll(async () => {
    // Cleanup
    await prisma.users.deleteMany({
      where: { firebase_uid: { in: ['socket-unit-a', 'socket-unit-b'] } },
    });

    // Register users
    await request(app)
      .post('/api/v1/auth/register')
      .send({ provider: 'google', idToken: MOCK_TOKEN_A });

    const userRecordA = await prisma.users.findUnique({
      where: { firebase_uid: 'socket-unit-a' },
    });
    userIdA = userRecordA!.id;

    await request(app)
      .post('/api/v1/auth/register')
      .send({ provider: 'google', idToken: MOCK_TOKEN_B });

    const userRecordB = await prisma.users.findUnique({
      where: { firebase_uid: 'socket-unit-b' },
    });
    userIdB = userRecordB!.id;

    // Start Socket.io server
    httpServer = createServer();
    socketServer = new SocketServer();
    socketServer.initialize(httpServer);

    port = await new Promise<number>((resolve) => {
      httpServer.listen(0, () => {
        const addr = httpServer.address();
        resolve(addr && typeof addr === 'object' ? addr.port : 3001);
      });
    });

    // Connect clients
    clientSocketA = ioClient(`http://localhost:${port}`, {
      query: { token: MOCK_TOKEN_A },
    });

    clientSocketB = ioClient(`http://localhost:${port}`, {
      query: { token: MOCK_TOKEN_B },
    });

    await Promise.all([
      new Promise<void>((resolve) => clientSocketA.on('connect', () => resolve())),
      new Promise<void>((resolve) => clientSocketB.on('connect', () => resolve())),
    ]);
  });

  afterAll(async () => {
    clientSocketA?.disconnect();
    clientSocketB?.disconnect();
    await new Promise<void>((resolve) => httpServer.close(() => resolve()));
    await prisma.users.deleteMany({
      where: { firebase_uid: { in: ['socket-unit-a', 'socket-unit-b'] } },
    });
    await prisma.$disconnect();
  });

  test('socket connects with authentication', () => {
    expect(clientSocketA.connected).toBe(true);
    expect(clientSocketB.connected).toBe(true);
  });

  test('notifyUser sends event with versioned envelope', async () => {
    const received = await new Promise<any>((resolve) => {
      clientSocketA.once('test.envelope', resolve);
      socketServer.notifyUser(userIdA, 'test.envelope', envelope({ message: 'hello' }));
      setTimeout(() => resolve(null), 1000);
    });

    expect(received).not.toBeNull();
    expect(received.v).toBe(1);
    expect(received.data.message).toBe('hello');
  });

  test('message event includes required fields', async () => {
    const received = await new Promise<any>((resolve) => {
      clientSocketA.once('speed_dating.message.created', resolve);
      socketServer.notifyUser(
        userIdA,
        'speed_dating.message.created',
        envelope({
          sessionId: 'session-123',
          message: {
            id: 'msg-123',
            senderId: userIdB,
            content: 'Hello there!',
            createdAt: new Date().toISOString(),
          },
        }),
      );
      setTimeout(() => resolve(null), 1000);
    });

    expect(received).not.toBeNull();
    expect(received.v).toBe(1);
    expect(received.data.sessionId).toBe('session-123');
    expect(received.data).toEqual(
      expect.objectContaining({
        message: expect.objectContaining({
          id: 'msg-123',
          senderId: userIdB,
          content: 'Hello there!',
        }),
      }),
    );
  });

  test('notifyUser targets only specified user', async () => {
    let receivedByA = false;
    let receivedByB = false;

    clientSocketA.once('targeted.msg', () => {
      receivedByA = true;
    });
    clientSocketB.once('targeted.msg', () => {
      receivedByB = true;
    });

    socketServer.notifyUser(userIdA, 'targeted.msg', envelope({ ok: true }));
    await new Promise((resolve) => setTimeout(resolve, 300));

    expect(receivedByA).toBe(true);
    expect(receivedByB).toBe(false);
  });

  test('multi-device broadcast sends to all user connections', async () => {
    const clientA2 = ioClient(`http://localhost:${port}`, {
      query: { token: MOCK_TOKEN_A },
    });

    await new Promise<void>((resolve) => {
      clientA2.on('connect', () => resolve());
    });

    let count = 0;
    clientSocketA.once('multi.test', () => count++);
    clientA2.once('multi.test', () => count++);

    socketServer.notifyUser(userIdA, 'multi.test', envelope({ ok: true }));
    await new Promise((resolve) => setTimeout(resolve, 300));

    expect(count).toBe(2);
    clientA2.disconnect();
  });

  test('room isolation prevents message leakage', async () => {
    let receivedByA = false;
    let receivedByB = false;

    clientSocketA.once('isolated.msg', () => {
      receivedByA = true;
    });
    clientSocketB.once('isolated.msg', () => {
      receivedByB = true;
    });

    socketServer.notifyUser(userIdA, 'isolated.msg', envelope({ ok: true }));
    await new Promise((resolve) => setTimeout(resolve, 300));

    expect(receivedByA).toBe(true);
    expect(receivedByB).toBe(false);
  });

  test('socket disconnect is handled gracefully', async () => {
    const tempClient = ioClient(`http://localhost:${port}`, {
      query: { token: MOCK_TOKEN_A },
    });

    await new Promise<void>((resolve) => {
      tempClient.on('connect', () => resolve());
    });

    expect(tempClient.connected).toBe(true);
    tempClient.disconnect();
    await new Promise((resolve) => setTimeout(resolve, 200));
    expect(tempClient.connected).toBe(false);
  });

  test('notifyUser with non-existent user does not throw', () => {
    expect(() => {
      socketServer.notifyUser('non-existent-id', 'test.event', envelope({ ok: true }));
    }).not.toThrow();
  });

  test('emits system.error on unexpected typing relay failure', async () => {
    const findUniqueSpy = jest
      .spyOn(appPrisma.matches, 'findUnique')
      .mockRejectedValueOnce(new Error('DB unavailable'));

    const errorEvent = await new Promise<any>((resolve) => {
      clientSocketA.once('error', resolve);

      clientSocketA.emit('typing', {
        chatType: 'permanent',
        chatId: '11111111-1111-1111-8111-111111111111',
        isTyping: true,
      });

      setTimeout(() => resolve(null), 1500);
    });

    expect(errorEvent).not.toBeNull();
    expect(errorEvent.v).toBe(1);
    expect(errorEvent.data.code).toBe('WS_TYPING_RELAY_FAILED');

    findUniqueSpy.mockRestore();
  });
});

describe('Socket Contract Integration', () => {
  let httpServer: HttpServer;
  let port: number;

  const tokenA = 'mock:google:socket-contract-a:socket-contract-a@socket-contract.test';
  const tokenB = 'mock:google:socket-contract-b:socket-contract-b@socket-contract.test';

  beforeAll(async () => {
    await prisma.$connect();

    httpServer = createServer(app);
    contractSocketServer.initialize(httpServer);

    port = await new Promise<number>((resolve) => {
      httpServer.listen(0, () => {
        const addr = httpServer.address();
        resolve(addr && typeof addr === 'object' ? addr.port : 3001);
      });
    });
  });

  beforeEach(async () => {
    await prisma.$executeRaw`DELETE FROM speed_dating_messages`;
    await prisma.$executeRaw`DELETE FROM speed_dating_sessions`;
    await prisma.$executeRaw`DELETE FROM matching_queue`;
    await prisma.$executeRaw`DELETE FROM user_blocks`;
    await prisma.$executeRaw`DELETE FROM matches`;
    await prisma.$executeRaw`DELETE FROM messages`;
    await prisma.$executeRaw`DELETE FROM profiles WHERE user_id IN (SELECT id FROM users WHERE email LIKE '%@socket-contract.test')`;
    await prisma.$executeRaw`DELETE FROM users WHERE email LIKE '%@socket-contract.test'`;

    await setupUser({
      token: tokenA,
      birthDate: '1996-06-10',
      gender: 'Male',
      searchGender: 'women',
      latitude: 25.033,
      longitude: 121.5654,
    });

    await setupUser({
      token: tokenB,
      birthDate: '1997-08-14',
      gender: 'Female',
      searchGender: 'men',
      latitude: 25.034,
      longitude: 121.565,
    });
  });

  afterAll(async () => {
    await new Promise<void>((resolve) => {
      contractSocketServer.getIO()?.close(() => resolve());
    });

    await new Promise<void>((resolve) => {
      httpServer.close(() => resolve());
    });

    await prisma.$disconnect();
  });

  test('emits move_to_permanent_requested immediately and session.ended { reason: graduated } when conversion succeeds', async () => {
    const socketA: ClientSocket = ioClient(`http://localhost:${port}`, {
      query: { token: tokenA },
    });

    const socketB: ClientSocket = ioClient(`http://localhost:${port}`, {
      query: { token: tokenB },
    });

    await Promise.all([
      new Promise<void>((resolve) => socketA.on('connect', () => resolve())),
      new Promise<void>((resolve) => socketB.on('connect', () => resolve())),
    ]);

    const firstJoin = await request(app)
      .post('/api/v1/matching/queue/join')
      .set('Authorization', `Bearer ${tokenA}`);

    expect(firstJoin.status).toBe(200);

    const secondJoin = await request(app)
      .post('/api/v1/matching/queue/join')
      .set('Authorization', `Bearer ${tokenB}`);

    expect(secondJoin.status).toBe(200);
    expect(secondJoin.body.data.state).toBe('matched');

    const sessionId = secondJoin.body.data.sessionId as string;
    const requesterUser = await prisma.users.findUnique({
      where: { firebase_uid: 'socket-contract-a' },
      select: { id: true },
    });

    expect(requesterUser).not.toBeNull();

    let requestPhaseEvent: any = null;
    socketB.once('speed_dating.session.move_to_permanent_requested', (payload) => {
      requestPhaseEvent = payload;
    });

    const requestMove = await request(app)
      .post(`/api/v1/matching/sessions/${sessionId}/move-to-permanent/request`)
      .set('Authorization', `Bearer ${tokenA}`);

    expect(requestMove.status).toBe(200);

    await new Promise((resolve) => setTimeout(resolve, 400));
    expect(requestPhaseEvent).not.toBeNull();
    expect(requestPhaseEvent.v).toBe(1);
    expect(requestPhaseEvent.data.sessionId).toBe(sessionId);
    expect(requestPhaseEvent.data.requestedByUserId).toBe(requesterUser!.id);

    const [endedA, endedB] = await Promise.all([
      new Promise<any>((resolve) => {
        socketA.once('speed_dating.session.ended', resolve);
        setTimeout(() => resolve(null), 1500);
      }),
      new Promise<any>((resolve) => {
        socketB.once('speed_dating.session.ended', resolve);
        setTimeout(() => resolve(null), 1500);
      }),
      request(app)
        .post(`/api/v1/matching/sessions/${sessionId}/move-to-permanent/respond`)
        .set('Authorization', `Bearer ${tokenB}`)
        .send({ accept: true }),
    ]);

    for (const event of [endedA, endedB]) {
      expect(event).not.toBeNull();
      expect(event.v).toBe(1);
      expect(event.data.sessionId).toBe(sessionId);
      expect(event.data.reason).toBe('graduated');
      expect(typeof event.data.matchId).toBe('string');
      expect(event.data.matchId.length).toBeGreaterThan(0);
    }

    socketA.disconnect();
    socketB.disconnect();
  }, 15000); // Increase timeout to 15 seconds

  test('emits normalized decision in speed_dating.session.final_decision_updated', async () => {
    const socketB: ClientSocket = ioClient(`http://localhost:${port}`, {
      query: { token: tokenB },
    });

    await new Promise<void>((resolve) => socketB.on('connect', () => resolve()));

    await request(app)
      .post('/api/v1/matching/queue/join')
      .set('Authorization', `Bearer ${tokenA}`);

    const secondJoin = await request(app)
      .post('/api/v1/matching/queue/join')
      .set('Authorization', `Bearer ${tokenB}`);

    expect(secondJoin.status).toBe(200);
    expect(secondJoin.body.data.state).toBe('matched');

    const sessionId = secondJoin.body.data.sessionId as string;

    await prisma.speed_dating_sessions.update({
      where: { id: sessionId },
      data: {
        status: 'awaiting_decision',
        user_a_decision: 'pending',
        user_b_decision: 'pending',
      },
    });

    const decisionEvent = await new Promise<any>((resolve) => {
      socketB.once('speed_dating.session.final_decision_updated', resolve);

      void request(app)
        .post(`/api/v1/matching/sessions/${sessionId}/final-decision`)
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ decision: 'YES' })
        .then(() => undefined);

      setTimeout(() => resolve(null), 1500);
    });

    expect(decisionEvent).not.toBeNull();
    expect(decisionEvent.v).toBe(1);
    expect(decisionEvent.data.sessionId).toBe(sessionId);
    expect(decisionEvent.data.decision).toBe('yes');

    socketB.disconnect();
  }, 15000); // Increase timeout to 15 seconds


  // Test as real matching and chatting case
  test('receives speed_dating.message.created via socket when counterpart sends a message via API', async () => {
    const socketA: ClientSocket = ioClient(`http://localhost:${port}`, {
      query: { token: tokenA },
    });

    const socketB: ClientSocket = ioClient(`http://localhost:${port}`, {
      query: { token: tokenB },
    });

    await Promise.all([
      new Promise<void>((resolve, reject) => {
        socketA.on('connect', () => resolve());
        socketA.on('connect_error', (err) => reject(new Error(`Socket A connect successed: ${err.message}`)));
      }),
      new Promise<void>((resolve, reject) => {
        socketB.on('connect', () => resolve());
        socketB.on('connect_error', (err) => reject(new Error(`Socket B connect failed: ${err.message}`)));
      }),
    ]);

    // 1. Both join queue and get matched
    await request(app).post('/api/v1/matching/queue/join').set('Authorization', `Bearer ${tokenA}`);
    const joinRes = await request(app)
      .post('/api/v1/matching/queue/join')
      .set('Authorization', `Bearer ${tokenB}`);

    const sessionId = joinRes.body.data.sessionId as string;

    // 2. Wrap event listener in a Promise, resolve immediately upon receiving push (no dead waiting)
    const socketEventPromise = new Promise<any>((resolve, reject) => {
      socketA.once('speed_dating.message.created', resolve);
      // Explicitly throw error if not received within 3 seconds to avoid infinite timeout
      setTimeout(() => reject(new Error('No socket push received after 3 seconds, please check Controller')), 3000);
    });

    // 3. User B sends a message via the REST API
    const sendRes = await request(app)
      .post(`/api/v1/matching/sessions/${sessionId}/messages`)
      .set('Authorization', `Bearer ${tokenB}`)
      .send({ content: 'Hello from B!' });

    expect(sendRes.status).toBe(201);

    // 4. Wait for and retrieve the instantaneous socket push data
    const receivedMessage = await socketEventPromise;

    // 5. Verify content
    expect(receivedMessage.v).toBe(1);
    expect(receivedMessage.data.sessionId).toBe(sessionId);
    expect(receivedMessage.data.message.content).toBe('Hello from B!');

    socketA.disconnect();
    socketB.disconnect();
  }, 15000); // Increase timeout to 15 seconds
});
