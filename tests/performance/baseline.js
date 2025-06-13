// K6 Performance test for mail server
// Run with: k6 run baseline.js

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Define metrics
const errorRate = new Rate('errors');

// Test configuration
export const options = {
  stages: [
    { duration: '2m', target: 10 },   // Ramp up to 10 users
    { duration: '5m', target: 10 },   // Stay at 10 users
    { duration: '2m', target: 20 },   // Ramp up to 20 users
    { duration: '5m', target: 20 },   // Stay at 20 users
    { duration: '2m', target: 0 },    // Ramp down to 0
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests must complete below 500ms
    errors: ['rate<0.1'],             // Error rate must be below 10%
  },
};

const BASE_URL = 'https://mail.summitethic.com';

export default function () {
  // Test 1: Homepage
  let response = http.get(BASE_URL);
  check(response, {
    'Homepage status is 200': (r) => r.status === 200,
    'Homepage load time < 500ms': (r) => r.timings.duration < 500,
  }) || errorRate.add(1);
  
  sleep(1);
  
  // Test 2: API Health Check
  response = http.get(`${BASE_URL}/api/v1/get/status/version`);
  check(response, {
    'API status is 200': (r) => r.status === 200,
    'API response time < 200ms': (r) => r.timings.duration < 200,
  }) || errorRate.add(1);
  
  sleep(1);
  
  // Test 3: Static Assets
  response = http.get(`${BASE_URL}/css/app.css`);
  check(response, {
    'Static asset status is 200': (r) => r.status === 200,
    'Static asset cached': (r) => r.headers['Cache-Control'] !== undefined,
  }) || errorRate.add(1);
  
  sleep(Math.random() * 3 + 1); // Random sleep between 1-4 seconds
}

export function handleSummary(data) {
  return {
    'performance-results.json': JSON.stringify(data),
    stdout: textSummary(data, { indent: ' ', enableColors: true }),
  };
}
