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
const goveeScanAddress = process.env.GOVEE_LAN_SCAN_ADDRESS || '239.255.255.250';
const goveeScanPort = Number.parseInt(process.env.GOVEE_LAN_SCAN_PORT || '4001', 10);
const goveeListenPort = Number.parseInt(process.env.GOVEE_LAN_LISTEN_PORT || '4002', 10);
const goveeCommandPort = 4003;
const deviceCacheLifetimeMs = 5 * 60 * 1000;
const discovery = { socket: null, error: null, ready: null, devices: new Map() };

if (!Number.isInteger(port) || port < 1 || port > 65535) {
  throw new Error('Optional HTTP port must be an integer from 1 through 65535.');
}
if (!Number.isInteger(goveeScanPort) || goveeScanPort < 1 || goveeScanPort > 65535 ||
    !Number.isInteger(goveeListenPort) || goveeListenPort < 1 || goveeListenPort > 65535 ||
    net.isIP(goveeScanAddress) !== 4) {
  throw new Error('Govee discovery addresses and ports must be valid IPv4 UDP destinations.');
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
  // Govee LAN API requests are an envelope whose `cmd` and `data` both live
  // under `msg`: {"msg":{"cmd":"ptReal","data":{"command":[…]}}}.
  // `cmd` at the outer level is valid JSON but is ignored by the device.
  const payload = Buffer.from(JSON.stringify({ msg: { cmd: 'ptReal', data: { command } } }), 'utf8');
  const socket = dgram.createSocket(net.isIP(ip) === 6 ? 'udp6' : 'udp4');
  return new Promise((resolve, reject) => {
    socket.send(payload, udpPort, ip, error => {
      socket.close();
      if (error) reject(error); else resolve(payload.length);
    });
  });
}

function currentDevices() {
  const cutoff = Date.now() - deviceCacheLifetimeMs;
  for (const [ip, device] of discovery.devices) {
    if (device.lastSeen < cutoff) discovery.devices.delete(ip);
  }
  return [...discovery.devices.values()]
    .sort((left, right) => left.ip.localeCompare(right.ip))
    .map(({ lastSeen, ...device }) => device);
}

function rememberDevice(message, remote) {
  if (!message || message.cmd !== 'scan' || !message.data || typeof message.data !== 'object') return;
  const data = message.data;
  if (net.isIP(remote.address) !== 4) return;
  discovery.devices.set(remote.address, {
    ip: remote.address,
    device: typeof data.device === 'string' ? data.device : '',
    sku: typeof data.sku === 'string' ? data.sku : '',
    bleVersionHard: typeof data.bleVersionHard === 'string' ? data.bleVersionHard : '',
    wifiVersionHard: typeof data.wifiVersionHard === 'string' ? data.wifiVersionHard : '',
    lastSeen: Date.now()
  });
}

function startDiscoveryListener() {
  discovery.ready = new Promise(resolve => {
    const socket = dgram.createSocket('udp4');
    let starting = true;
    socket.on('message', (payload, remote) => {
      try {
        const packet = JSON.parse(payload.toString('utf8'));
        rememberDevice(packet?.msg, remote);
      } catch {
        // Ignore unrelated UDP traffic and malformed packets on this port.
      }
    });
    socket.on('error', error => {
      discovery.error = error;
      if (discovery.socket === socket) discovery.socket = null;
      if (starting) resolve();
    });
    socket.bind(goveeListenPort, '0.0.0.0', () => {
      starting = false;
      discovery.socket = socket;
      discovery.error = null;
      resolve();
    });
  });
}

function delay(milliseconds) {
  return new Promise(resolve => setTimeout(resolve, milliseconds));
}

function sendDiscoveryPacket() {
  const packet = Buffer.from(JSON.stringify({
    msg: { cmd: 'scan', data: { account_topic: 'reserve' } }
  }), 'utf8');
  const socket = dgram.createSocket('udp4');
  return new Promise((resolve, reject) => {
    const finish = error => {
      socket.close();
      if (error) reject(error); else resolve();
    };
    socket.once('error', finish);
    socket.bind(0, '0.0.0.0', () => {
      try {
        socket.setMulticastTTL(1);
        socket.send(packet, goveeScanPort, goveeScanAddress, finish);
      } catch (error) {
        finish(error);
      }
    });
  });
}

async function discoverDevices() {
  await discovery.ready;
  if (!discovery.socket) {
    const detail = discovery.error?.code === 'EADDRINUSE'
      ? `UDP port ${goveeListenPort} is already used by another LAN-control service.`
      : (discovery.error?.message || 'Unable to listen for Govee discovery replies.');
    throw new Error(detail);
  }
  await sendDiscoveryPacket();
  await delay(250);
  await sendDiscoveryPacket();
  await delay(1250);
  return currentDevices();
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

  if (request.method === 'GET' && request.url === '/api/devices') {
    reply(response, 200, { devices: currentDevices() });
    return;
  }

  if (request.method === 'POST' && request.url === '/api/discover') {
    try {
      reply(response, 200, { devices: await discoverDevices() });
    } catch (error) {
      reply(response, 503, { error: error.message || 'Unable to discover Govee LAN devices.' });
    }
    return;
  }

  if (request.method === 'POST' && request.url === '/api/send') {
    try {
      const { ip, command } = await readJson(request);
      if (typeof ip !== 'string' || net.isIP(ip) === 0) throw new Error('Device IP must be a valid IPv4 or IPv6 address.');
      if (!validCommands(command)) throw new Error('Command must contain 1–128 canonical base64 packets of exactly 20 bytes each.');
      const bytes = await sendUdp(ip, goveeCommandPort, command);
      reply(response, 200, { ip, port: goveeCommandPort, bytes });
    } catch (error) {
      reply(response, 400, { error: error.message || 'Unable to send UDP command.' });
    }
    return;
  }

  reply(response, 404, { error: 'Not found.' });
});

startDiscoveryListener();

server.listen(port, host, () => {
  console.log(`H61A8 scene lab: http://${host}:${port}`);
  console.log('Use Ctrl+C to stop. This server accepts connections only from this computer.');
});
