// Mock of ustated (package ustate-exporter) on 127.0.0.1:11052.
// Protect 7.3+ reads storage from ustate.spaceState / ustate.peripheralState over gRPC
// instead of unifi-core, and skips the spaces sync until both streams have sent data.
'use strict';

const fs = require('fs');
const path = require('path');

const MODULES = '/usr/share/unifi-core/app/node_modules';
const grpc = require(path.join(MODULES, '@grpc/grpc-js'));
const protoLoader = require(path.join(MODULES, '@grpc/proto-loader'));

const ADDRESS = '127.0.0.1:11052';
const SRV = '/srv';
// Size the space from the video dir: it may be a separate mount (e.g. NFS) under /srv.
const VIDEO_DIR = '/srv/unifi-protect/video';
const UPDATE_INTERVAL_MS = 30000;

const load = (file) => grpc.loadPackageDefinition(protoLoader.loadSync(path.join(__dirname, file), {
    keepCase: false,
    enums: String,
    defaults: false,
}));
const storage = load('storage.proto').unifi.firmware.storage.v2;
const accessory = load('accessory.proto').unifi.firmware.accessory.v1;

// Same device, uuid and RAID layout as unifi-core/app/mockStorageAPIClient.js.
function getSpaces() {
    let stats;
    try {
        stats = fs.statfsSync(VIDEO_DIR);
    } catch {
        try {
            stats = fs.statfsSync(SRV);
        } catch (err) {
            console.error(`statfs ${SRV} failed: ${err.message}`);
            return [];
        }
    }

    const totalBytes = stats.blocks * stats.bsize;
    const usedBytes = (stats.blocks - stats.bfree) * stats.bsize;
    const reservedBytes = (stats.bfree - stats.bavail) * stats.bsize;

    return [{
        device: 'md3',
        state: 'SPACE_STATE_HEALTHY',
        type: 'SPACE_TYPE_DATA',
        info: {
            filesystem: {
                uuid: 'a8ca30a1-8742-45e0-a9fe-a901f4c7be21',
                type: 'FILESYSTEM_TYPE_EXT4',
                mountPoint: SRV,
                mountStatus: 'FILESYSTEM_MOUNT_STATUS_MOUNTED',
                totalBytes,
                usedBytes,
                systemReservedBytes: reservedBytes,
            },
            raid: [{
                device: 'md3',
                state: 'RAID_STATE_HEALTHY',
                info: {
                    uuid: 'raid-uuid-12345',
                    syncAction: 'RAID_SYNC_ACTION_NONE',
                    currentLevel: 'RAID_LEVEL_1',
                    configuredLevel: 'RAID_LEVEL_1',
                    expectedParityCount: 1,
                    sizeKilobytes: Math.floor(totalBytes / 1024),
                },
                members: {
                    size: totalBytes,
                    names: ['sda', 'sdb'],
                    expectedCount: 2,
                    maxConfiguredCount: 2,
                },
            }],
        },
    }];
}

// Server-streaming: send state now and keep the stream open like the real ustated.
function spaceState(call) {
    const send = () => call.write({space: getSpaces()});
    send();
    const timer = setInterval(send, UPDATE_INTERVAL_MS);
    const stop = () => clearInterval(timer);
    call.on('cancelled', stop);
    call.on('close', stop);
    call.on('error', stop);
}

// No storage expansion units: an empty response clears Protect's expansion state.
function peripheralState(call) {
    call.write({});
    call.on('error', () => {});
}

const server = new grpc.Server();
server.addService(storage.StorageAPI.service, {spaceState});
server.addService(accessory.AccessoryAPI.service, {peripheralState});
server.bindAsync(ADDRESS, grpc.ServerCredentials.createInsecure(), (err) => {
    if (err) {
        console.error(`Failed to bind ${ADDRESS}: ${err.message}`);
        process.exit(1);
    }
    console.log(`ustated mock listening on ${ADDRESS}`);
});
