import { Socket } from 'socket.io';
import { createAuthVerifier } from '../services/auth/auth-verifier';
import { UserRepository } from '../repositories/user-repository';

const authVerifier = createAuthVerifier();
const userRepository = new UserRepository();

declare module 'socket.io' {
  interface SocketData {
    dbUserId: string;
    firebaseUid: string;
  }
}

export async function socketAuthMiddleware(socket: Socket, next: (err?: Error) => void) {
  try {
    // Support getting token from auth payload (new standard) or query string (legacy)
    const token = socket.handshake.auth?.token || socket.handshake.query?.token;

    if (!token) {
      return next(new Error('AUTH_MISSING'));
    }

    if (typeof token !== 'string') {
      return next(new Error('AUTH_INVALID'));
    }

    // Verify Firebase token
    let identity;
    try {
      identity = await authVerifier.verifyIdToken(token);
    } catch (error) {
      console.error('🔴 [Socket Auth] Firebase Token valid error:', error);
      return next(new Error('AUTH_INVALID'));
    }

    // Find user in database
    const user = await userRepository.findByFirebaseUid(identity.uid);
    if (!user) {
      console.error(`🔴 [Socket Auth] DB didn't find user (UID: ${identity.uid})`);
      return next(new Error('AUTH_USER_NOT_FOUND'));
    }

    // Check if user is banned
    if (user.is_banned) {
      return next(new Error('AUTH_BANNED'));
    }

    // Store user identifiers in socket data
    socket.data.dbUserId = user.id;
    socket.data.firebaseUid = identity.uid;

    next();
  } catch (error) {
    console.error('🔴 [Socket Auth] Prisma did not connect to DB:', error);
    next(new Error('AUTH_INVALID'));
  }
}
