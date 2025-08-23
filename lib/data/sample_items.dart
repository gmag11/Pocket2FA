import '../models/two_factor_item.dart';

final List<TwoFactorItem> sampleItems = [
  TwoFactorItem(service: 'Amazon', account: 'user@example.com', twoFa: '110 254', nextTwoFa: '165 719', group: 'Personal'),
  TwoFactorItem(service: 'Anydesk', account: 'device-iPhone-15', twoFa: '630 542', nextTwoFa: '492 255', group: 'Devices'),
  TwoFactorItem(service: 'Atlassian', account: 'user@example.com', twoFa: '049 996', nextTwoFa: '531 958', group: 'Work'),
  TwoFactorItem(service: 'Google', account: 'user@gmail.com', twoFa: '857 740', nextTwoFa: '108 089', group: 'Personal'),
  TwoFactorItem(service: 'Microsoft', account: 'user@hotmail.com', twoFa: '695 269', nextTwoFa: '346 987', group: 'Admin'),
  TwoFactorItem(service: 'Cloudflare', account: 'user@example.com', twoFa: '929 141', nextTwoFa: '416 287', group: 'Personal'),
  TwoFactorItem(service: 'Autodesk', account: 'user@example.com', twoFa: '921 253', nextTwoFa: '239 551', group: 'Work'),
  TwoFactorItem(service: 'AWS SSO', account: 'user@example.com', twoFa: '560 595', nextTwoFa: '091 891', group: 'Work'),
  TwoFactorItem(service: 'BingX', account: 'user@example.com', twoFa: '540 784', nextTwoFa: '485 662', group: 'Personal'),
  TwoFactorItem(service: 'GitHost', account: 'user@example.com', twoFa: '541 678', nextTwoFa: '123 456', group: 'Work'),
  TwoFactorItem(service: 'Dropbox', account: 'user@example.com', twoFa: '312 450', nextTwoFa: '654 321', group: 'Personal'),
  TwoFactorItem(service: 'Google', account: 'user@example.com', twoFa: '782 901', nextTwoFa: '888 777', group: 'Personal'),
  TwoFactorItem(service: 'Microsoft', account: 'user@example.com', twoFa: '450 120', nextTwoFa: '333 222', group: 'Work'),
  TwoFactorItem(service: 'Facebook', account: 'user@example.com', twoFa: '223 334', nextTwoFa: '101 202', group: 'Personal'),
  TwoFactorItem(service: 'Twitter', account: 'user@example.com', twoFa: '998 001', nextTwoFa: '909 808', group: 'Personal'),
  TwoFactorItem(service: 'CustomApp', account: 'service_account', twoFa: '010 203', nextTwoFa: '010 011', group: 'Admin'),
];
