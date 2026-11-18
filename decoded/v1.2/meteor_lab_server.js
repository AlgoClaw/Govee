#!/usr/bin/env node
'use strict';

/*
 * Local-only companion for meteor_lab.html.
 * It serves the H61A8 scene catalog and sends validated ptReal JSON envelopes
 * by UDP. A browser cannot use a UDP socket directly.
 */

const dgram = require('node:dgram');
const fs = require('node:fs');
const http = require('node:http');
const net = require('node:net');
const path = require('node:path');

const host = '127.0.0.1';
const port = Number.parseInt(process.argv[2] || '8080', 10);
const pagePath = path.join(__dirname, 'meteor_lab.html');
const sceneCatalogPath = path.join(__dirname, 'JSONs', 'H61A8_debug.json');
const maxBodyBytes = 64 * 1024;

if (!Number.isInteger(port) || port < 1 || port > 65535) {
  throw new Error('Optional HTTP port must be an integer from 1 through 65535.');
}

function reply(response, status, body, type = 'application/json; charset=utf-8') {
  response.writeHead(status, {
    'content-type': type,
    'cache-control': 'no-store',
    'content-security-policy': "default-src 'self'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; base-uri 'none'"
  });
  response.end(typeof body === 'string' ? body : JSON.stringify(body));
}

function validCommands(command) {
  if (!Array.isArray(command) || command.length < 1 || command.length > 128) return null;
  const packets = [];
  for (const entry of command) {
    if (typeof entry !== 'string' || !/^[A-Za-z0-9+/]+={0,2}$/.test(entry)) return null;
    const packet = Buffer.from(entry, 'base64');
    if (packet.length !== 20 || packet.toString('base64') !== entry) return null;
    packets.push(packet);
  }
  return packets;
}

function readSceneCatalog() {
  const scenes = JSON.parse(fs.readFileSync(sceneCatalogPath, 'utf8'));
  if (!Array.isArray(scenes)) throw new Error('H61A8 debug catalog is not an array.');
  return scenes.map((scene, index) => {
    const paramsHex = scene.params_b16 || '';
    if (typeof scene.name !== 'string' || !Number.isInteger(scene.sceneCode_b10) ||
        !Number.isInteger(scene.sceneId_b10) || !Number.isInteger(scene.scenceParamId_b10) ||
        !Number.isInteger(scene.sceneType_b10) || !/^(?:[0-9a-f]{2})*$/i.test(paramsHex)) {
      throw new Error(`Invalid H61A8 catalog entry at index ${index}.`);
    }
    return {
      id: index,
      name: scene.name,
      sceneId: scene.sceneId_b10,
      scenceParamId: scene.scenceParamId_b10,
      sceneType: scene.sceneType_b10,
      sceneCode: scene.sceneCode_b10,
      paramsHex: paramsHex.toLowerCase()
    };
  });
}

function readJson(request) {
  return new Promise((resolve, reject) => {
    let size = 0;
    let body = '';
    request.setEncoding('utf8');
    request.on('data', chunk => {
      size += Buffer.byteLength(chunk);
      if (size > maxBodyBytes) {
        reject(new Error('Request is too large.'));
        request.destroy();
        return;
      }
      body += chunk;
    });
    request.on('end', () => {
      try { resolve(JSON.parse(body)); } catch { reject(new Error('Request body must be JSON.')); }
    });
    request.on('error', reject);
  });
}

function sendUdp(ip, udpPort, command) {
  const payload = Buffer.from(JSON.stringify({ msg: { data: { command } }, cmd: 'ptReal' }), 'utf8');
  const socket = dgram.createSocket(net.isIP(ip) === 6 ? 'udp6' : 'udp4');
  return new Promise((resolve, reject) => {
    socket.send(payload, udpPort, ip, error => {
      socket.close();
      if (error) reject(error); else resolve(payload.length);
    });
  });
}

const server = http.createServer(async (request, response) => {
  if (request.method === 'GET' && (request.url === '/' || request.url === '/meteor_lab.html')) {
    try {
      reply(response, 200, fs.readFileSync(pagePath, 'utf8'), 'text/html; charset=utf-8');
    } catch {
      reply(response, 500, { error: 'meteor_lab.html could not be read.' });
    }
    return;
  }

  if (request.method === 'GET' && request.url === '/api/scenes') {
    try {
      const scenes = readSceneCatalog();
      reply(response, 200, { model: 'H61A8', scenes });
    } catch (error) {
      reply(response, 500, { error: error.message || 'Unable to load the H61A8 scene catalog.' });
    }
    return;
  }

  if (request.method === 'POST' && request.url === '/api/send') {
    try {
      const { ip, port: udpPort, command } = await readJson(request);
      const parsedPort = Number(udpPort);
      if (typeof ip !== 'string' || net.isIP(ip) === 0) throw new Error('Device IP must be a valid IPv4 or IPv6 address.');
      if (!Number.isInteger(parsedPort) || parsedPort < 1 || parsedPort > 65535) throw new Error('UDP port must be an integer from 1 through 65535.');
      if (!validCommands(command)) throw new Error('Command must contain 1–128 canonical base64 packets of exactly 20 bytes each.');
      const bytes = await sendUdp(ip, parsedPort, command);
      reply(response, 200, { ip, port: parsedPort, bytes });
    } catch (error) {
      reply(response, 400, { error: error.message || 'Unable to send UDP command.' });
    }
    return;
  }

  reply(response, 404, { error: 'Not found.' });
});

server.listen(port, host, () => {
  console.log(`H61A8 scene lab: http://${host}:${port}`);
  console.log('Use Ctrl+C to stop. This server accepts connections only from this computer.');
});
