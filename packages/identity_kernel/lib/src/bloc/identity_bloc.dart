import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'identity_event.dart';
import 'identity_state.dart';
import '../services/identity_service.dart';

class IdentityBloc extends Bloc<IdentityEvent, IdentityState> {
  final IdentityService _identityService;
  StreamSubscription? _identitySubscription;

  IdentityBloc(this._identityService) : super(const IdentityInitial()) {
    on<CreateIdentity>(_onCreateIdentity);
    on<LoadIdentity>(_onLoadIdentity);
    on<UpdateProfile>(_onUpdateProfile);
    on<ResolveUsername>(_onResolveUsername);
    on<CheckAvailability>(_onCheckAvailability);
    on<RefreshIdentity>(_onRefresh);
    on<Logout>(_onLogout);
  }

  Future<void> _onCreateIdentity(
    CreateIdentity event,
    Emitter<IdentityState> emit,
  ) async {
    emit(const IdentityLoading());
    try {
      final identity = await _identityService.createIdentity(
        phoneNumber: event.phoneNumber,
        username: event.username,
        displayName: event.displayName,
      );
      emit(IdentityAuthenticated(identity));
    } catch (e) {
      emit(IdentityError(e.toString()));
    }
  }

  Future<void> _onLoadIdentity(
    LoadIdentity event,
    Emitter<IdentityState> emit,
  ) async {
    emit(const IdentityLoading());
    try {
      final identity = await _identityService.getIdentity(event.identityId);
      emit(IdentityAuthenticated(identity));
    } catch (e) {
      emit(const IdentityUnauthenticated());
    }
  }

  Future<void> _onUpdateProfile(
    UpdateProfile event,
    Emitter<IdentityState> emit,
  ) async {
    emit(const IdentityLoading());
    try {
      final current = state;
      if (current is IdentityAuthenticated) {
        final updated = await _identityService.updateProfile(
          event.identityId,
          current.identity.profile.copyWith(
            displayName: event.displayName,
            bio: event.bio,
            avatarUrl: event.avatarUrl ?? current.identity.profile.avatarUrl,
          ),
        );
        emit(IdentityAuthenticated(updated));
      }
    } catch (e) {
      emit(IdentityError(e.toString()));
    }
  }

  Future<void> _onResolveUsername(
    ResolveUsername event,
    Emitter<IdentityState> emit,
  ) async {
    emit(const IdentityLoading());
    try {
      final identity = await _identityService.resolveUsername(event.username);
      emit(IdentityAuthenticated(identity));
    } catch (e) {
      emit(IdentityError(e.toString()));
    }
  }

  Future<void> _onCheckAvailability(
    CheckAvailability event,
    Emitter<IdentityState> emit,
  ) async {
    final available =
        await _identityService.checkUsernameAvailability(event.username);
    if (available) {
      emit(state);
    } else {
      emit(IdentityError('Username ${event.username} is already taken'));
    }
  }

  Future<void> _onRefresh(
    RefreshIdentity event,
    Emitter<IdentityState> emit,
  ) async {
    final current = state;
    if (current is IdentityAuthenticated) {
      add(LoadIdentity(current.identity.id));
    }
  }

  Future<void> _onLogout(
    Logout event,
    Emitter<IdentityState> emit,
  ) async {
    await _identitySubscription?.cancel();
    emit(const IdentityUnauthenticated());
  }

  @override
  Future<void> close() {
    _identitySubscription?.cancel();
    return super.close();
  }
}
