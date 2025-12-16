
class CreateUserPayload {
  final String name;
  final String last_name_1;
  final String? last_name_2;

  final String dni;
  final String? mail;

  final String? phone;
  final String? birthday; 
  final String? sex; 

  final String password;
  final bool? isValidate;

  final bool? patient;
  final bool? revisor;
  final bool? coordinator;

  final int? groupPatientId;  
  final int? groupRevisorId;  
  final List<int>? groupsRevisor;

  CreateUserPayload({
    required this.name,
    required this.last_name_1,
    this.last_name_2,
    required this.dni,
    this.mail,
    this.phone,
    this.birthday,
    this.sex,
    required this.password,
    this.isValidate,
    this.patient,
    this.revisor,
    this.coordinator,
    this.groupPatientId,
    this.groupRevisorId,
    this.groupsRevisor,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'last_name_1': last_name_1,
        if (last_name_2 != null) 'last_name_2': last_name_2,
        'dni': dni,
        if (mail != null) 'mail': mail,
        if (phone != null) 'phone': phone,
        if (birthday != null) 'birthday': birthday,
        if (sex != null) 'sex': sex,
        'password': password,
        if (isValidate != null) 'isValidate': isValidate,
        if (patient != null) 'patient': patient,
        if (revisor != null) 'revisor': revisor,
        if (coordinator != null) 'coordinator': coordinator,
        if (groupPatientId != null) 'groupPatientId': groupPatientId,
        if (groupRevisorId != null) 'groupRevisorId': groupRevisorId,
        if (groupsRevisor != null) 'groupsRevisor': groupsRevisor,
      };
}
