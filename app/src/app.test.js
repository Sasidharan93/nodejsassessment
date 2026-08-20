const request = require('supertest');
const app = require('./app');

describe('GET /healthz', () => {
  it('returns 200 ok', async () => {
    const res = await request(app).get('/healthz');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});
