import {EventEmitter} from 'events';
import {exec} from 'child_process';

// Helper to run the system df command and parse srv space
function getSrvSpace() {
    return new Promise((resolve) => {
        exec('df -B1 /srv', (err, stdout) => {
            // Fallback default values (100 GB) if the command fails
            const fallback = {
                totalBytes: 100000000000, // 100 GB
                usedBytes: 15300000000,   // ~15.3 GB
                availBytes: 84700000000   // ~84.7 GB
            };

            if (err || ! stdout) {
                resolve(fallback);
                return;
            }

            const lines = stdout.trim().split('\n');
            if (lines.length < 2) {
                resolve(fallback);
                return;
            }

            const parts = lines[1].split(/\s+/);
            const totalBytes = parseInt(parts[1], 10);
            const usedBytes = parseInt(parts[2], 10);
            const availBytes = parseInt(parts[3], 10);

            resolve({
                totalBytes: isNaN(totalBytes) ? fallback.totalBytes : totalBytes,
                usedBytes: isNaN(usedBytes) ? fallback.usedBytes : usedBytes,
                availBytes: isNaN(availBytes) ? fallback.availBytes : availBytes
            });
        });
    });
}

// Helper to mimic gRPC response format
class MockGrpcResponse {
    constructor(data) {
        this._data = data;
    }

    toObject() {
        return this._data;
    }
}

// Mimics a gRPC ReadableStream (supports both objects and Promises)
class MockGrpcStream extends EventEmitter {
    constructor(methodName, dataPromise) {
        super();
        this.methodName = methodName;
        this.cancelled = false;

        // Resolve immediately or once the system command finishes
        Promise.resolve(dataPromise)
            .then((data) => {
                this.emitData(data);
            })
            .catch((err) => {
                this.emitError(err);
            });
    }

    cancel() {
        if (! this.cancelled) {
            this.cancelled = true;
            this.emit('close');
            this.emit('cancelled');
        }
    }

    getPeer() {
        return '127.0.0.1:50051';
    }

    emitData(data) {
        if (! this.cancelled) {
            this.emit('data', new MockGrpcResponse(data));
        }
    }

    emitError(err) {
        if (! this.cancelled) {
            this.emit('error', err);
        }
    }
}

export class StorageAPIClient {
    constructor(address, credentials, options) {
        this.address = address;
        this.credentials = credentials;
        this.options = options;
        this.activeStreams = new Map();
    }

    _createStream(methodName, defaultData) {
        const stream = new MockGrpcStream(methodName, defaultData);
        this.activeStreams.set(methodName, stream);
        stream.on('close', () => this.activeStreams.delete(methodName));
        return stream;
    }

    // --- Mocked gRPC Endpoints ---

    spaceState(request) {
        const dataPromise = getSrvSpace().then((space) => ({
            spaceList: [
                {
                    device: 'md3',
                    type: 1,  // SpaceType.SPACE_TYPE_DATA -> "data"
                    state: 2, // SpaceState.SPACE_STATE_HEALTHY -> "healthy"
                    info: {
                        filesystem: {
                            uuid: 'a8ca30a1-8742-45e0-a9fe-a901f4c7be21',
                            type: 1,        // FilesystemType.FILESYSTEM_TYPE_EXT4 -> "EXT4"
                            mountPoint: '/srv',
                            mountStatus: 1, // FilesystemMountStatus.FILESYSTEM_MOUNT_STATUS_MOUNTED -> "MOUNTED"
                            totalBytes: space.totalBytes,
                            usedBytes: space.usedBytes,
                            systemReservedBytes: Math.round(space.totalBytes * 0.01) // 1% reserved
                        },
                        raidList: [
                            {
                                device: 'md3',
                                state: 1, // RaidState.RAID_STATE_HEALTHY -> "HEALTHY"
                                info: {
                                    uuid: 'raid-uuid-12345',
                                    syncAction: 1, // RaidSyncAction.RAID_SYNC_ACTION_NONE -> "NONE"
                                    currentLevel: 1, // RaidLevel.RAID_LEVEL_1 -> "1" (RAID 1)
                                    configuredLevel: 1,
                                    expectedParityCount: 1,
                                    sizeKilobytes: Math.round(space.totalBytes / 1024),
                                    actionProgressPercent: 100,
                                    actionCompleteEstimateSeconds: 0
                                },
                                members: {
                                    expectedCount: 2,
                                    maxConfiguredCount: 2,
                                    namesList: ['sda', 'sdb'],
                                    size: space.totalBytes
                                }
                            }
                        ],
                        pool: null,
                        cache: null,
                        issuesList: []
                    }
                }
            ]
        }));

        return this._createStream('spaceState', dataPromise);
    }

    diskState(request) {
        const dataPromise = getSrvSpace().then((space) => ({
            slotList: [
                {
                    index: 1,
                    state: 3, // SlotState.SLOT_STATE_PRESENT -> "PRESENT"
                    disk: {
                        device: '/dev/sda',
                        status: 1, // DeviceHealthStatus.DEVICE_HEALTH_STATUS_HEALTHY -> "healthy"
                        info: {
                            smartInfo: {
                                type: 1,         // DiskType.DISK_TYPE_HDD -> "HDD"
                                protocol: 1,     // DiskProtocol.DISK_PROTOCOL_SATA -> "sata"
                                sectorFormat: 2, // DiskSectorFormat.DISK_SECTOR_FORMAT_512N -> "512n"
                                firmware: 'WD10FFBX',
                                model: 'WDC WD10EFAX-68KN9N0',
                                serial: 'WD-W1C2E3G4',
                                sizeBytes: space.totalBytes, // Matched dynamically with host srv size
                                hdd: {rpm: 5400},
                                sata: {version: 'SATA 3.0'}
                            },
                            smartAttr: {
                                hdd: {badSectorCount: 0},
                                powerOnHours: 12000,
                                temperatureCelsius: 32
                            },
                            raidState: 2,       // DiskRaidState.DISK_RAID_STATE_ACTIVE
                            assignmentState: 3, // DiskAssignmentState.DISK_ASSIGNMENT_STATE_ASSIGNED -> "assigned" (initialized)
                            abnormalInfo: {
                                riskReasonsList: [],
                                incompatibleReasonsList: []
                            }
                        },
                        stats: {},
                        identifier: 'wd-w1c2e3g4-identifier'
                    }
                },
                {
                    index: 2,
                    state: 3, // SlotState.SLOT_STATE_PRESENT -> "PRESENT"
                    disk: {
                        device: '/dev/sdb',
                        status: 1, // DeviceHealthStatus.DEVICE_HEALTH_STATUS_HEALTHY -> "healthy"
                        info: {
                            smartInfo: {
                                type: 1,         // DiskType.DISK_TYPE_HDD -> "HDD"
                                protocol: 1,     // DiskProtocol.DISK_PROTOCOL_SATA -> "sata"
                                sectorFormat: 2, // DiskSectorFormat.DISK_SECTOR_FORMAT_512N -> "512n"
                                firmware: 'WD10FFBX',
                                model: 'WDC WD10EFAX-68KN9N0',
                                serial: 'WD-W5F6G7H8',
                                sizeBytes: space.totalBytes, // Matched dynamically with host srv size
                                hdd: {rpm: 5400},
                                sata: {version: 'SATA 3.0'}
                            },
                            smartAttr: {
                                hdd: {badSectorCount: 0},
                                powerOnHours: 11950,
                                temperatureCelsius: 33
                            },
                            raidState: 2,       // DiskRaidState.DISK_RAID_STATE_ACTIVE
                            assignmentState: 3, // DiskAssignmentState.DISK_ASSIGNMENT_STATE_ASSIGNED -> "assigned" (initialized)
                            abnormalInfo: {
                                riskReasonsList: [],
                                incompatibleReasonsList: []
                            }
                        },
                        stats: {},
                        identifier: 'wd-w5f6g7h8-identifier'
                    }
                }
            ]
        }));

        return this._createStream('diskState', dataPromise);
    }

    flashState(request) {
        return this._createStream('flashState', {
            slotList: [
                {
                    index: 0,
                    state: 3,
                    disk: {
                        device: '/dev/mmcblk0',
                        status: 1,
                        info: {
                            smartInfo: {
                                type: 2,
                                protocol: 2,
                                sectorFormat: 2,
                                firmware: 'EMMC-1.0',
                                model: 'eMMC 16GB',
                                serial: 'EMMC-SERIAL-0',
                                sizeBytes: 16000000000,
                                sata: null
                            },
                            smartAttr: {
                                ssd: {lifespanPercent: 98},
                                powerOnHours: 42000,
                                temperatureCelsius: 38
                            },
                            raidState: 1,
                            assignmentState: 3,
                            abnormalInfo: null
                        }
                    }
                }
            ]
        });
    }

    cacheSlotState(request) {
        return this._createStream('cacheSlotState', {slotList: []});
    }

    storageSettings(request) {
        return this._createStream('storageSettings', {
            setting: {
                mode: 1,
                global: {
                    raid: {
                        level: 1,
                        useRaidHotSpare: {value: false}
                    },
                    enclosureSettingOverridesList: []
                }
            }
        });
    }

    sDCardState(request) {
        return this._createStream('sDCardState', {
            slotList: [
                {
                    index: 1,
                    state: 3,
                    sdcard: {
                        status: 1,
                        info: {
                            sizeBytes: 128000000000,
                            notSupportedReasonsList: []
                        }
                    }
                }
            ]
        });
    }
}
