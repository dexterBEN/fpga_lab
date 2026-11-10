import '../models/register_mode.dart';
import '../models/register_snapshot.dart';

abstract interface class RegisterRepository {
  Future<void> connect();

  Future<bool> ping();

  Future<RegisterSnapshot> getState();

  Future<RegisterSnapshot> loadParallel(int value);

  Future<RegisterSnapshot> shiftBit(int bit);

  Future<RegisterSnapshot> selectMode(RegisterMode mode);

  Future<void> disconnect();

  Stream<bool> get connectionChanges;

  bool get isConnected;

  Future<void> dispose();
}
