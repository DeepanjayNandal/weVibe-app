import request from 'supertest';
import 'dotenv/config';
import { app } from '../src/server';

describe('Auth: Register Endpoint - Type Validation', () => {

  it('should return 400 if provider is not a string', async () => {
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({
        provider: 123, // wrong type
        idToken: 'mock:google:test-003:user3@example.com'
      });

    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('error');
  });

  it('should return 400 if idToken is not a string', async () => {
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({
        provider: 'mock',
        idToken: { token: 'abc' } // wrong type
      });

    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('error');
  });

  it('should return 400 if both fields have invalid types', async () => {
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({
        provider: true,  // wrong type
        idToken: 999     // wrong type
      });

    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('error');
  });

});