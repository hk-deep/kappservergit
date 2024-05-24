import 'package:jaguar_jwt/jaguar_jwt.dart';
import 'package:my_server/helpers/config.dart';

class User {
  User(
      {required this.name,
      required this.email,
      required this.token,
      required this.password,
      required this.salt,
      this.exP = 0,
      this.level = 1,
      this.listOfchapterStatus = const [],
      this.language = "en",
      this.theoreticalLevel = 1,
      this.dicoUnlock = const [],
      this.progress = 1,
      this.settings = const [],
      this.stats = const [],
      required this.toolValues});

  //main userInfo
  String email;
  String name;
  String token;
  String password;
  String salt;

  //secondary userInfo
  int exP;
  int level;
  List listOfchapterStatus;
  String language;
  int theoreticalLevel;
  List stats;
  int progress;
  List settings;
  List dicoUnlock;
  List toolValues;
  // var profileImage = Image(
  //   image: AssetImage('assets/images/KappLogo.jpeg'),
  // ); //not yet

  void updateUser(Map update) {
    if (update['exP'] != null) {
      exP = update['exP'];
    }
    if (update['level'] != null) {
      level = update['level'];
    }
    if (update['language'] != null) {
      language = update['language'];
    }
    if (update['stats'] != null) {
      stats = update['stats'];
    }
    if (update['progress'] != null) {
      progress = update['progress'];
    }
    if (update['settings'] != null) {
      settings = update['settings'];
    }
    if (update['dicoUnlock'] != null) {
      dicoUnlock = update['dicoUnlock'];
    }
    if (update['toolValues'] != null) {
      toolValues = update['toolValues'];
    }
    if (update['listOfchapterStatus'] != null) {
      listOfchapterStatus = update['listOfchapterStatus'];
    } //can't update theoretical elvel
  }

  static User fromDynamicMap(Map<String, dynamic> map) => User(
      name: map['name'],
      email: map['email'],
      token: signToken(map['email']),
      password: map['password'],
      salt: map['salt'],
      language: map['language'],
      dicoUnlock: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      listOfchapterStatus: [
        [1, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0]
      ],
      exP: 0,
      level: 1,
      theoreticalLevel: 1,
      stats: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 100, 0, 0],
      progress: 1,
      toolValues: [
        {
          "age": "2003",
          "career": "Mid-career",
          "time": 1.0,
          "dependent": true,
          "netWorth": "1",
          "level": "Low",
          "expenses": "1",
          "risk": "idk",
          "approach": "moderate",
          "handsOn": "Passive",
          "interest": "I don't think so",
          "preferences": "None",
          "limitations": false,
          "strategy": "None", //first tool default values
        },
        {}, //risk questionnaire default values (none needed)
        {
          '1234order': [],
        }, //goals
      ],
      settings: [0, 1]);

  Map userInfo() {
    return {
      'email': email,
      'name': name,
      'token': token,
      'XP': exP,
      'language': language,
      'level': level,
      'tlevel': theoreticalLevel,
      'chapterStatus': listOfchapterStatus,
      'progress': progress,
      'stats': stats,
      'dico': dicoUnlock,
      'settings': settings,
    };
  }

  static String signToken(String userEmail) {
    final claimSet = JwtClaim(
        issuer: 'Dart Server',
        subject: userEmail,
        issuedAt: DateTime.now(),
        maxAge: const Duration(hours: 12));
    const String secret = Properties.jwtSecret;
    return issueJwtHS256(claimSet, secret);
  }
}
