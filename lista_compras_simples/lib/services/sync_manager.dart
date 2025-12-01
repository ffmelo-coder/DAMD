import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'database_service.dart';
import '../utils/updated_at_helper.dart';
import 'package:flutter/foundation.dart' as fnd;

class SyncManager {
  SyncManager._internal();

  static final SyncManager instance = SyncManager._internal();

  static const List<String> _candidates = [
    'http://localhost:3000',
    'SEU NGROK AQUI',
    'http://10.0.2.2:3000',
  ];

  String? _activeBaseUrl;

  String get _base => _activeBaseUrl ?? _candidates.first;

  StreamSubscription? _sub;
  bool _running = false;
  Timer? _debounceTimer;

  bool autoSyncEnabled = false;

  void start() {
    if (_running) return;
    _running = true;
    if (autoSyncEnabled) {
      _sub = Connectivity().onConnectivityChanged.listen((dynamic result) {
        bool online = false;
        if (result is List) {
          if (result.isNotEmpty) {
            final first = result.first;
            online = first != ConnectivityResult.none;
          }
        } else if (result is ConnectivityResult) {
          online = result != ConnectivityResult.none;
        }
        if (online) {
          _attemptSyncIfHealthy();
        }
      });

      Connectivity().checkConnectivity().then((result) {
        if (result != ConnectivityResult.none) {
          _attemptSyncIfHealthy();
        }
      });

      try {
        DatabaseService.instance.onLocalChange = () {
          scheduleSyncDebounced();
        };
      } catch (_) {}
    } else {
      try {
        DatabaseService.instance.onLocalChange = null;
      } catch (_) {}
    }
  }

  void stop() {
    _sub?.cancel();
    _running = false;
    _debounceTimer?.cancel();
    try {
      DatabaseService.instance.onLocalChange = null;
    } catch (_) {}
  }

  void setAutoSyncEnabled(bool enabled) {
    autoSyncEnabled = enabled;
    if (!_running) return;
    if (enabled) {
      try {
        DatabaseService.instance.onLocalChange = () {
          scheduleSyncDebounced();
        };
      } catch (_) {}
      try {
        if (_sub == null) {
          _sub = Connectivity().onConnectivityChanged.listen((dynamic result) {
            bool online = false;
            if (result is List) {
              if (result.isNotEmpty)
                online = result.first != ConnectivityResult.none;
            } else if (result is ConnectivityResult) {
              online = result != ConnectivityResult.none;
            }
            if (online) _attemptSyncIfHealthy();
          });
        }
      } catch (_) {}
    } else {
      try {
        DatabaseService.instance.onLocalChange = null;
      } catch (_) {}
      try {
        _sub?.cancel();
        _sub = null;
      } catch (_) {}
    }
  }

  void scheduleSyncDebounced({Duration delay = const Duration(seconds: 1)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () async {
      fnd.debugPrint('[SyncManager] Debounced sync triggered');
      await syncNow();
    });
  }

  Future<void> _syncPending() async {
    final pending = await DatabaseService.instance.getPendingSyncs();
    fnd.debugPrint('[SyncManager] Pending items to sync: ${pending.length}');
    if (pending.isEmpty) return;

    for (final row in pending) {
      fnd.debugPrint(
        '[SyncManager] Processing sync entry id=${row['id']} action=${row['action']} taskId=${row['taskId']}',
      );
      try {
        final id = row['id'] as int;
        final action = row['action'] as String? ?? '';
        final payload = row['payload'] != null
            ? jsonDecode(row['payload'] as String)
            : null;
        final taskId = row['taskId'] as String?;

        if (action == 'create') {
          if (payload is Map<String, dynamic>) {
            try {
              if ((payload['name'] == null ||
                      (payload['name'] is String &&
                          (payload['name'] as String).trim().isEmpty)) &&
                  payload.containsKey('title') &&
                  payload['title'] != null) {
                payload['name'] = payload['title'];
              }
            } catch (_) {}
          }

          fnd.debugPrint(
            '[SyncManager] POST /tasks body=${jsonEncode(payload)}',
          );
          final res = await http.post(
            Uri.parse('$_base/tasks'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          );
          fnd.debugPrint(
            '[SyncManager] POST /tasks -> ${res.statusCode} body=${res.body}',
          );
          if (res.statusCode == 200 || res.statusCode == 201) {
            fnd.debugPrint(
              '[SyncManager] create -> server responded ${res.statusCode} for sync id=$id',
            );

            try {
              final body = res.body;
              if (body.isNotEmpty) {
                var created = jsonDecode(body) as Map<String, dynamic>;
                if (created['updatedAt'] != null) {
                  final dt = parseUpdatedAt(created['updatedAt']);
                  if (dt != null) created['updatedAt'] = dt.toIso8601String();
                }

                if (taskId != null &&
                    created['id'] != null &&
                    created['id'] != taskId) {
                  try {
                    final localTask = await DatabaseService.instance.read(
                      taskId,
                    );
                    if (localTask != null) {
                      bool sIsEmpty(dynamic v) {
                        if (v == null) return true;
                        if (v is String) return v.trim().isEmpty;
                        if (v is List) return v.isEmpty;
                        if (v is Map) return v.isEmpty;
                        return false;
                      }

                      if (sIsEmpty(created['title']) &&
                          localTask.title.isNotEmpty) {
                        created['title'] = localTask.title;
                      }
                      if (sIsEmpty(created['description']) &&
                          localTask.description.isNotEmpty) {
                        created['description'] = localTask.description;
                      }
                      if (sIsEmpty(created['priority']) &&
                          localTask.priority.isNotEmpty) {
                        created['priority'] = localTask.priority;
                      }

                      if ((created['categoryId'] == null ||
                              (created['categoryId'] is String &&
                                  (created['categoryId'] as String)
                                      .trim()
                                      .isEmpty)) &&
                          localTask.categoryId.isNotEmpty) {
                        created['categoryId'] = localTask.categoryId;
                      }

                      created['createdAt'] =
                          created['createdAt'] ??
                          localTask.createdAt.toIso8601String();
                      created['updatedAt'] =
                          created['updatedAt'] ??
                          localTask.updatedAt.toIso8601String();

                      if ((created['photoPath'] == null ||
                              (created['photoPath'] is String &&
                                  (created['photoPath'] as String)
                                      .trim()
                                      .isEmpty)) &&
                          localTask.photoPath != null &&
                          localTask.photoPath!.isNotEmpty) {
                        created['photoPath'] = localTask.photoPath;
                      }
                      if ((created['photosPaths'] == null ||
                              (created['photosPaths'] is String &&
                                  (created['photosPaths'] as String)
                                      .trim()
                                      .isEmpty)) &&
                          localTask.photosPaths != null &&
                          localTask.photosPaths!.isNotEmpty) {
                        created['photosPaths'] = localTask.photosPaths!.join(
                          '|',
                        );
                      }

                      if ((created['dueDate'] == null ||
                              (created['dueDate'] is String &&
                                  (created['dueDate'] as String)
                                      .trim()
                                      .isEmpty)) &&
                          localTask.dueDate != null) {
                        created['dueDate'] = localTask.dueDate!
                            .toIso8601String();
                      }
                      if ((created['reminderTime'] == null ||
                              (created['reminderTime'] is String &&
                                  (created['reminderTime'] as String)
                                      .trim()
                                      .isEmpty)) &&
                          localTask.reminderTime != null) {
                        created['reminderTime'] = localTask.reminderTime!
                            .toIso8601String();
                      }

                      if ((created['completed'] == null) &&
                          localTask.completed) {
                        created['completed'] = 1;
                      }
                      if ((created['completedAt'] == null ||
                              (created['completedAt'] is String &&
                                  (created['completedAt'] as String)
                                      .trim()
                                      .isEmpty)) &&
                          localTask.completedAt != null) {
                        created['completedAt'] = localTask.completedAt!
                            .toIso8601String();
                      }
                      if ((created['completedBy'] == null ||
                              (created['completedBy'] is String &&
                                  (created['completedBy'] as String)
                                      .trim()
                                      .isEmpty)) &&
                          localTask.completedBy != null) {
                        created['completedBy'] = localTask.completedBy;
                      }

                      if ((created['latitude'] == null ||
                              created['latitude'] == '') &&
                          localTask.latitude != null) {
                        created['latitude'] = localTask.latitude;
                      }
                      if ((created['longitude'] == null ||
                              created['longitude'] == '') &&
                          localTask.longitude != null) {
                        created['longitude'] = localTask.longitude;
                      }
                      if ((created['locationName'] == null ||
                              (created['locationName'] is String &&
                                  (created['locationName'] as String)
                                      .trim()
                                      .isEmpty)) &&
                          localTask.locationName != null) {
                        created['locationName'] = localTask.locationName;
                      }
                      if ((created['locationHistory'] == null ||
                              (created['locationHistory'] is String &&
                                  (created['locationHistory'] as String)
                                      .trim()
                                      .isEmpty)) &&
                          localTask.locationHistory != null &&
                          localTask.locationHistory!.isNotEmpty) {
                        try {
                          created['locationHistory'] = jsonEncode(
                            localTask.locationHistory,
                          );
                        } catch (_) {
                          created['locationHistory'] = localTask.locationHistory
                              .toString();
                        }
                      }
                    }
                  } catch (e) {
                    fnd.debugPrint(
                      '[SyncManager] Failed to merge local draft $taskId: ${e.toString()}',
                    );
                  }
                }

                await DatabaseService.instance.upsertTaskFromMap(created);
                if (created['id'] != null) {
                  await DatabaseService.instance.markTaskAsSynced(
                    created['id'],
                  );
                }

                if (taskId != null &&
                    created['id'] != null &&
                    created['id'] != taskId) {
                  try {
                    await DatabaseService.instance.deleteLocalOnly(taskId);
                  } catch (e) {
                    fnd.debugPrint(
                      '[SyncManager] Failed to remove local draft $taskId: ${e.toString()}',
                    );
                  }
                }
              } else if (taskId != null) {
                await DatabaseService.instance.markTaskAsSynced(taskId);
              }
            } catch (e) {
              fnd.debugPrint(
                '[SyncManager] create -> error processing server response: ${e.toString()}',
              );
              if (taskId != null) {
                await DatabaseService.instance.markTaskAsSynced(taskId);
              }
            }
            await DatabaseService.instance.deleteSyncEntry(id);
          } else {
            try {
              fnd.debugPrint(
                '[SyncManager] create -> server returned ${res.statusCode} body=${res.body}',
              );
            } catch (_) {
              fnd.debugPrint(
                '[SyncManager] create -> server returned ${res.statusCode} (failed to read body)',
              );
            }
          }
        } else if (action == 'update') {
          if (taskId == null) {
            await DatabaseService.instance.deleteSyncEntry(id);
            continue;
          }

          final serverRes = await http.get(Uri.parse('$_base/tasks/$taskId'));
          DateTime? serverUpdated;
          Map<String, dynamic>? serverData;
          if (serverRes.statusCode == 200) {
            serverData = jsonDecode(serverRes.body) as Map<String, dynamic>;
            if (serverData['updatedAt'] != null) {
              serverUpdated = parseUpdatedAt(serverData['updatedAt']);

              if (serverUpdated != null) {
                serverData['updatedAt'] = serverUpdated.toIso8601String();
              }
            }
            fnd.debugPrint(
              '[SyncManager] fetched server task $taskId updatedAt=$serverData["updatedAt"]',
            );
          }

          final localMap = payload as Map<String, dynamic>;
          final localUpdated = localMap['updatedAt'] != null
              ? DateTime.tryParse(localMap['updatedAt'] as String)
              : null;

          bool serverHasMeaningful =
              serverData != null && _serverHasMeaningful(serverData);

          if (serverUpdated != null &&
              localUpdated != null &&
              serverUpdated.isAfter(localUpdated) &&
              serverHasMeaningful) {
            fnd.debugPrint(
              '[SyncManager] LWW: server wins for task $taskId (server=${serverUpdated.toIso8601String()} local=${localUpdated.toIso8601String()})',
            );
            await DatabaseService.instance.upsertTaskFromMap(serverData);
            await DatabaseService.instance.deleteSyncEntry(id);
          } else {
            fnd.debugPrint(
              '[SyncManager] LWW: local wins for task $taskId (server=${serverUpdated?.toIso8601String() ?? 'null'} local=${localUpdated?.toIso8601String() ?? 'null'})',
            );

            try {
              if ((localMap['name'] == null ||
                      (localMap['name'] is String &&
                          (localMap['name'] as String).trim().isEmpty)) &&
                  localMap.containsKey('title') &&
                  localMap['title'] != null) {
                localMap['name'] = localMap['title'];
              }
            } catch (_) {}

            fnd.debugPrint(
              '[SyncManager] PUT /tasks/$taskId body=${jsonEncode(localMap)}',
            );
            final res = await http.put(
              Uri.parse('$_base/tasks/$taskId'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(localMap),
            );
            fnd.debugPrint(
              '[SyncManager] PUT $taskId -> ${res.statusCode} body=${res.body}',
            );
            if (res.statusCode == 200 || res.statusCode == 204) {
              localMap['synced'] = 1;
              await DatabaseService.instance.markTaskAsSynced(taskId);
              await DatabaseService.instance.deleteSyncEntry(id);
            }
          }
        } else if (action == 'delete') {
          if (taskId == null) {
            await DatabaseService.instance.deleteSyncEntry(id);
            continue;
          }
          final res = await http.delete(Uri.parse('$_base/tasks/$taskId'));
          fnd.debugPrint('[SyncManager] DELETE $taskId -> ${res.statusCode}');

          if (res.statusCode == 200 ||
              res.statusCode == 204 ||
              res.statusCode == 404) {
            try {
              await DatabaseService.instance.deleteLocalOnly(taskId);
            } catch (e) {
              fnd.debugPrint(
                '[SyncManager] Failed to delete local task $taskId: ${e.toString()}',
              );
            }
            await DatabaseService.instance.deleteSyncEntry(id);
          }
        } else {
          await DatabaseService.instance.deleteSyncEntry(id);
        }
      } catch (e) {
        break;
      }
    }
  }

  bool _serverHasMeaningful(Map<String, dynamic> m) {
    bool isMeaningful(dynamic v) {
      if (v == null) return false;
      if (v is String) return v.trim().isNotEmpty;
      if (v is num) return true;
      if (v is List) return v.isNotEmpty;
      if (v is Map) return v.isNotEmpty;
      return true;
    }

    if (isMeaningful(m['title'] ?? m['name'])) return true;
    if (isMeaningful(m['description'])) return true;

    if (isMeaningful(m['items'])) return true;
    if (isMeaningful(m['summary'])) return true;

    if (isMeaningful(m['priority'])) return true;
    if (isMeaningful(m['categoryId'])) return true;

    if (isMeaningful(m['photoPath'])) return true;
    if (isMeaningful(m['photosPaths'])) return true;

    if (isMeaningful(m['dueDate'])) return true;
    if (isMeaningful(m['reminderTime'])) return true;

    if (m.containsKey('completed') && m['completed'] != null) return true;
    if (isMeaningful(m['completedAt'])) return true;
    if (isMeaningful(m['completedBy'])) return true;

    if (isMeaningful(m['latitude'])) return true;
    if (isMeaningful(m['longitude'])) return true;
    if (isMeaningful(m['locationName'])) return true;
    if (isMeaningful(m['locationHistory'])) return true;

    return false;
  }

  Map<String, dynamic> serverDataWithDefaults(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data;
    } catch (e) {
      return {};
    }
  }

  Future<bool> _isGatewayHealthy() async {
    try {
      if (_activeBaseUrl == null) {
        for (final candidate in _candidates) {
          fnd.debugPrint(
            '[SyncManager] Trying gateway candidate: $candidate/health',
          );
          try {
            final uri = Uri.parse('$candidate/health');
            final res = await http.get(uri).timeout(const Duration(seconds: 3));
            fnd.debugPrint(
              '[SyncManager] Candidate $candidate responded ${res.statusCode}',
            );
            if (res.statusCode == 200) {
              _activeBaseUrl = candidate;
              fnd.debugPrint(
                '[SyncManager] Resolved gateway baseUrl to $_activeBaseUrl',
              );
              return true;
            }
          } catch (e) {
            fnd.debugPrint(
              '[SyncManager] Candidate $candidate failed: ${e.toString()}',
            );
          }
        }
        fnd.debugPrint('[SyncManager] No gateway candidate healthy');
        return false;
      }

      fnd.debugPrint(
        '[SyncManager] Pinging previously-resolved gateway: $_activeBaseUrl/health',
      );
      final uri = Uri.parse('$_activeBaseUrl/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      fnd.debugPrint(
        '[SyncManager] Active gateway responded ${res.statusCode}',
      );
      if (res.statusCode == 200) return true;

      fnd.debugPrint(
        '[SyncManager] Previously active gateway unhealthy, resetting active base',
      );
      _activeBaseUrl = null;
      return false;
    } catch (e) {
      fnd.debugPrint(
        '[SyncManager] Gateway health check failed: ${e.toString()}',
      );
      _activeBaseUrl = null;
      return false;
    }
  }

  Future<void> _attemptSyncIfHealthy() async {
    final healthy = await _isGatewayHealthy();
    if (healthy) {
      fnd.debugPrint('[SyncManager] Gateway healthy — starting pending sync');

      DatabaseService.instance.startChangeBatch();
      try {
        await _syncPending();

        await _pullServerTasks();
      } finally {
        DatabaseService.instance.finishChangeBatch();
      }
    } else {
      fnd.debugPrint(
        '[SyncManager] Gateway not healthy — skipping sync for now',
      );
    }
  }

  Future<void> syncNow() async {
    await _attemptSyncIfHealthy();
  }

  Future<void> _pullServerTasks() async {
    try {
      final uri = Uri.parse('$_base/tasks');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) {
        fnd.debugPrint(
          '[SyncManager] Pull tasks: server responded ${res.statusCode}',
        );
        return;
      }
      final body = res.body;
      if (body.isEmpty) return;
      final data = jsonDecode(body);
      if (data is! List) return;
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          try {
            Map<String, dynamic> taskMap;
            if (item.containsKey('name') &&
                item.containsKey('items') &&
                !item.containsKey('title')) {
              final listName = item['name'] ?? '';
              final listDescription = item['description'] ?? '';

              final summary =
                  (item['items'] is List && (item['items'] as List).isNotEmpty)
                  ? ' (${(item['items'] as List).length} itens)'
                  : '';
              taskMap = {
                'id':
                    item['id'] ??
                    (DateTime.now().millisecondsSinceEpoch.toString()),
                'title': listName,
                'description': listDescription + summary,
                'completed': 0,
                'createdAt':
                    item['createdAt'] ?? DateTime.now().toIso8601String(),
                'updatedAt':
                    item['updatedAt'] ?? DateTime.now().toIso8601String(),
                'synced': 1,
              };
            } else {
              if (item['updatedAt'] != null) {
                final dt = parseUpdatedAt(item['updatedAt']);
                if (dt != null) item['updatedAt'] = dt.toIso8601String();
              }

              taskMap = Map<String, dynamic>.from(item);
            }

            final serverId = taskMap['id']?.toString();
            if (serverId != null &&
                await DatabaseService.instance.hasPendingDelete(serverId)) {
              fnd.debugPrint(
                '[SyncManager] Skipping server task $serverId because a local delete is pending',
              );
              continue;
            }

            await DatabaseService.instance.upsertTaskFromMap(taskMap);
            if (taskMap['id'] != null) {
              await DatabaseService.instance.markTaskAsSynced(taskMap['id']);
            }
          } catch (e) {
            fnd.debugPrint(
              '[SyncManager] Failed to upsert server task: ${e.toString()}',
            );
          }
        }
      }
      fnd.debugPrint('[SyncManager] Pulled ${data.length} tasks from server');
    } catch (e) {
      fnd.debugPrint('[SyncManager] Error pulling tasks: ${e.toString()}');
    }
  }
}
