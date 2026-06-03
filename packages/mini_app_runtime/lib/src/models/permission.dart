enum MiniAppPermission {
  none,
  identity,
  wallet,
  payments,
  camera,
  microphone,
  location,
  notifications,
  contacts,
}

const permissionLabels = {
  MiniAppPermission.identity: 'Read your profile (username, avatar)',
  MiniAppPermission.wallet: 'Read your wallet address and balance',
  MiniAppPermission.payments: 'Make payments on your behalf',
  MiniAppPermission.camera: 'Access your camera',
  MiniAppPermission.microphone: 'Access your microphone',
  MiniAppPermission.location: 'Access your location',
  MiniAppPermission.notifications: 'Send you notifications',
  MiniAppPermission.contacts: 'Read your contacts',
};
