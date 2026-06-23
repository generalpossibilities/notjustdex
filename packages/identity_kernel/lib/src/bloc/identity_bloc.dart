import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'identity_event.dart';
import 'identity_state.dart';
import '../services/identity_service.dart';
import '../services/authentication_service.dart';

/// Identity bloc — fully decentralized, no Go service dependency.
///
/// Events flow:
///   registerWithPasskey → on-chain registration
///   loginWithPasskey    → passkey assertion → wallet recovery → chain verify
///   loginWithWallet     → wallet ZKP → chain verify
///   loadIdentity        → fetch from chain (fallback to local cache)
class IdentityBloc extends Bloc<IdentityEvent, IdentityState> {
  final IdentityService _identityService;
  final AuthenticationService _authService;
  StreamSubscription? _identitySubscription;

  IdentityBloc({
    required IdentityService identityService,
    required AuthenticationService authService,
  })  : _identityService = identityService,
        _authService = authService,
        super(const IdentityInitial()) {
    on<RegisterWithPasskey>(_onRegisterWithPasskey);
    on<LoginWithPasskey>(_onLoginWithPasskey);
    on<LoginWithWallet>(_onLoginWithWallet);
    on<LoadIdentity>(_onLoadIdentity);
    on<UpdateProfile>(_onUpdateProfile);
    on<ResolveUsername>(_onResolveUsername);
    on<CheckAvailability>(_onCheckAvailability);
    on<RefreshIdentity>(_onRefresh);
    on<Logout>(_onLogout);
  }

  Future<void> _onRegisterWithPasskey(
    RegisterWithPasskey event,
    Emitter<IdentityState> emit,
  ) async {
    emit(const IdentityLoading());
    try {
      final identity = await _authService.registerWithPasskey(
        passkeyCredentialId: event.passkeyCredentialId,
        passkeyPublicKey: event.passkeyPublicKey,
        username: event.username,
        displayName: event.displayName,
        phoneNumber: event.phoneNumber,
      );
      emit(IdentityAuthenticated(identity));
    } catch (e) {
      emit(IdentityError(e.toString()));
    }
  }

  Future<void> _onLoginWithPasskey(
    LoginWithPasskey event,
    Emitter<IdentityState> emit,
  ) async {
    emit(const IdentityLoading());
    try {
      final identity = await _authService.loginWithPasskey(
        passkeyCredentialId: event.passkeyCredentialId,
        passkeySignature: event.passkeySignature,
      );
      emit(IdentityAuthenticated(identity));
    } catch (e) {
      emit(const IdentityUnauthenticated());
    }
  }

  Future<void> _onLoginWithWallet(
    LoginWithWallet event,
    Emitter<IdentityState> emit,
  ) async {
    emit(const IdentityLoading());
    try {
      final identity = await _authService.loginWithWallet(
        address: event.address,
        signature: event.signature,
        challenge: event.challenge,
      );
      emit(IdentityAuthenticated(identity));
    } catch (e) {
      emit(const IdentityUnauthenticated());
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
            avatarCid: event.avatarCid,
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
    await _authService.logout();
    emit(const IdentityUnauthenticated());
  }

  @override
  Future<void> close() {
    _identitySubscription?.cancel();
    return super.close();
  }
}
