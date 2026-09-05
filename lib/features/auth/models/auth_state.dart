enum UserRole { customer, delivery, admin }
enum UserStatus { approved, pending, rejected }

class UserAuthData {
  String countryCode;
  String phoneNumber;
  String generatedOtp;
  String fullName;
  String emailAddress;
  String deliveryAddress;
  bool isLocationGranted;
  UserRole role;
  UserStatus status;

  UserAuthData({
    this.countryCode = '+91',
    this.phoneNumber = '',
    this.generatedOtp = '185456',
    this.fullName = '',
    this.emailAddress = '',
    this.deliveryAddress = 'Saheed Nagar, Bhubaneswar',
    this.isLocationGranted = false,
    this.role = UserRole.customer,
    this.status = UserStatus.approved,
  });

  String get fullPhoneNumber => '$countryCode $phoneNumber';
}
