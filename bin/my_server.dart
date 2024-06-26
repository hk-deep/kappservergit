// Copyright (c) 2021, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
//import 'dart:html' as html;
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:jaguar_jwt/jaguar_jwt.dart';
import 'package:my_server/helpers/config.dart';
import 'package:mysql1/mysql1.dart';

import 'db.dart';
import 'package:path/path.dart' as path;
import './get_storage.dart';

import 'user_element.dart';

final connectionName = Platform.environment['CLOUD_SQL_CONNECTION_NAME'];
final dbUser = Platform.environment['DB_USER'];
final dbPassword = Platform.environment['DB_PASSWORD'];
final dbName = Platform.environment['DB_NAME'];

// Connect to the database
final settings = ConnectionSettings(
  host: connectionName!,
  user: dbUser,
  password: dbPassword,
  db: dbName,
);

Future<void> main() async {
  // If the "PORT" environment variable is set, listen to it. Otherwise, 8080.
  // https://cloud.google.com/run/docs/reference/container-contract#port
  final port = int.parse(Platform.environment['PORT'] ?? '8080');

  // See https://pub.dev/documentation/shelf/latest/shelf/Cascade-class.html
  final cascade = Cascade()
      // First, serve files from the 'public' directory
      //.add(_staticHandler)   //the cascade doesnt really work because it throws an error on that one, dont know what that is
      // If a corresponding file is not found, send requests to a `Router`
      .add(_router.call);

  // See https://pub.dev/documentation/shelf/latest/shelf_io/serve.html
  final server = await shelf_io.serve(
    // See https://pub.dev/documentation/shelf/latest/shelf/logRequests.html
    logRequests()
        // See https://pub.dev/documentation/shelf/latest/shelf/MiddlewareExtensions/addHandler.html
        .addHandler(cascade.handler),
    InternetAddress.anyIPv4, // Allows external connections
    port,
  );

  print('Serving at http://${server.address.host}:${server.port}');

  _watch.start();
}

final _router = shelf_router.Router()
  ..get('/storageTest', StorageBucket.bucketTestHandler)
  ..get('/lesson/<b>/<lng>', _lessonHandler)
  ..get('/images/<b>/<lng>', _imagesHandler)
  ..get('/quiz/<a>/<lng>', _quizHandler)
  ..get('/logo', _logoHandler)
  ..get('/api/changePasswordAndLogoutAllDevices/<email>',
      _logedOutAndChangedPasswordHandler)
  ..post('/api/changePassword', _passwordChangeHandler)
  ..post('/api/customers', _customerHandler) //all good
  ..post('/api/logout', (request) => Response.ok("Logout complete"))
  ..post('/api/auth', _authHandler) //all good
  ..post('/api/initlog', _initLogHandler) //allgod
  ..post('/api/tokenlog', _tokenLog) //allgood
  ..post('/api/contactUs', _contactUsHandler) //all good
  ..post('/api/del', _delHandler) //allgood
  ..post('/api/recovery', _recoveryEmailHandler)
  ..post('/api/friends', _friendsHandler)
  ..post('/api/addFriend', _addFriendHandler)
  ..post('/api/acceptRequest', _acceptFriendRequestHandler)
  ..post('/api/deleteFriend', _removeFriendHandler)
  ..post('/api/updateUser',
      _userUpdateHandler) //works, but to be tested further in app, and all values need to be strings
  ..post('/tools/<id>', _toolGetHandler)
  ..post('/tools/update/<id>', _toolUpdateHandler);

//docker build kappservergit -t europe-west9-docker.pkg.dev/x-circle-416916/myrep/firstkappimage:latest
//docker push europe-west9-docker.pkg.dev/x-circle-416916/myrep/firstkappimage:latest

//Friend handler
//
//
//
//

//we create two new databases, one dual with names of existing friendships "friends" and one with requests "friendRequests"
//first column of friend request is always the sender, second the receiver
//we also create a tag column in the users database
//right now anyone can pull anyones friends, we need to add a check to see if the user given corresponds to the token
//incomplete
Future<Response> _friendsHandler(Request request) async {
  var value = await utf8.decodeStream(request.read());
  var decodedValue = jsonDecode(value);
  String token = decodedValue['token'];
  String myId = decodedValue['myId'];
  if (_isValidToken(token)) {
    MySqlConnection conn =
        await MySqlConnection.connect(settings, isUnixSocket: true);
    //deleted to save some request time
    // Map myInfo = responseToList(
    //     await conn.query("SELECT name, tag FROM users WHERE email = '$subject'"))[0];
    //     String myId = "${myInfo["name"]}#${myInfo["tag"]}";
    List friends = responseToList(await conn.query(
        "SELECT CASE WHEN column1 = '$myId' THEN column2 WHEN column2 = '$myId' THEN column1 END AS other_column FROM friends WHERE '$myId' IN (column1, column2);")); //gets ids of the user's friends
    for (int i = 0; i < friends.length; i++) {
      List friendsId = friends[i]["other_column"].split("#");
      List retrieveFriend = responseToList(await conn.query(
          "SELECT name, exP, level, tag, avatar FROM users WHERE name = '${friendsId[0]}' AND tag = '${friendsId[1]}' "));
      if (retrieveFriend.isNotEmpty) {
        friends[i] = retrieveFriend[0];
      } else {
        friends.removeAt(i);
        i--;
      }
      //replaces friendId with Map of values for the friend
    }
    print("test1");
    List friendRequests = responseToList(await conn.query(
        "SELECT column1 FROM friendRequests WHERE column2 = '$myId'")); //gets ids of the user's friend requests
    conn.close();
    Map toSend = {"friends": friends, "friendRequests": friendRequests};

    return Response.ok(jsonEncode(toSend)); //list of maps of friends
  } else {
    return Response.notFound("Invalid Token");
  }
}

//same problem here, anyone with a valid token can add any friendrequest
//incomplete
Future<Response> _addFriendHandler(Request request) async {
  var value = await utf8.decodeStream(request.read());
  var decodedValue = jsonDecode(value);
  String token = decodedValue['token'];
  String identifier = decodedValue['identifier'];
  String myId = decodedValue['myId'];
  List nameAndTag = identifier.split("#");
  if (_isValidToken(token)) {
    MySqlConnection conn =
        await MySqlConnection.connect(settings, isUnixSocket: true);
    var results = await conn.query(
        "SELECT COUNT(*) as count FROM users WHERE name = '${nameAndTag[0]}' AND tag = '${nameAndTag[1]}'");
    if (results.first["count"] > 0) {
      conn.query("INSERT INTO friendRequests VALUES ('$myId', '$identifier')");
      conn.close();
      return Response.ok("Friend request sent");
    } else {
      conn.close();
      return Response.notFound("User not found");
    }
  } else {
    return Response.notFound("Invalid Token");
  }
}

//anyone can delete anything
//incomplete
Future<Response> _removeFriendHandler(Request request) async {
  var value = await utf8.decodeStream(request.read());
  var decodedValue = jsonDecode(value);
  String token = decodedValue['token'];
  String identifier = decodedValue['identifier'];
  String myId = decodedValue['myId'];
  if (_isValidToken(token)) {
    MySqlConnection conn =
        await MySqlConnection.connect(settings, isUnixSocket: true);
    conn.query(
        "DELETE FROM friends WHERE column1 = '$identifier' AND column2 = '$myId'");
    conn.query(
        "DELETE FROM friends WHERE column2 = '$identifier' AND column1 = '$myId'");
    conn.query(
        "DELETE FROM friendRequests WHERE column1 = '$identifier' AND column2 = '$myId'"); //first column is user who asked, second is user who received
    //above we delete the case where the user refuses the friend request
    conn.close();
    return Response.ok("Deleted"); //list of maps of friends
  } else {
    return Response.notFound("Invalid Token");
  }
}

Future<Response> _acceptFriendRequestHandler(Request request) async {
  var value = await utf8.decodeStream(request.read());
  var decodedValue = jsonDecode(value);
  String token = decodedValue['token'];
  String identifier = decodedValue['identifier'];
  String myId = decodedValue['myId'];
  if (_isValidToken(token)) {
    MySqlConnection conn =
        await MySqlConnection.connect(settings, isUnixSocket: true);
    List friendRequest = responseToList(await conn.query(
        "SELECT column1, column2 FROM friendRequests WHERE column1 = '$identifier' AND column2 = '$myId'"));
    if (friendRequest.isNotEmpty) {
      Map request = friendRequest[0];
      conn.query(
          "DELETE FROM friendRequests WHERE column1 = '$identifier' AND column2 = '$myId'");
      conn.query(
          "INSERT INTO friends VALUES ('${request["column1"]}', '${request["column2"]}')");
      List friendsId = identifier.split("#");
      Map newFriend = responseToList(await conn.query(
          "SELECT name, exP, level, tag, avatar FROM users WHERE name = '${friendsId[0]}' AND tag = '${friendsId[1]}'"))[0];
      conn.close();
      return Response.ok(jsonEncode(newFriend)); //sends back info on new friend
    } else {
      conn.close();
      return Response.notFound("No friend request found");
    }
  } else {
    return Response.notFound("Invalid Token");
  }
}

//
//
//
//
//
Future<Response> _logoHandler(Request request) async {
  String currentDirectory = path.dirname(Platform.script.toFilePath());
  String filePath =
      path.join(currentDirectory, "assets/KappLogoTransparent.png");

  final imageFile = File(filePath);
  if (await imageFile.exists()) {
    final imageBytes = await imageFile.readAsBytes();
    return Response.ok(imageBytes, headers: {'Content-Type': 'image/png'});
  } else {
    return Response.notFound('Image not found');
  }
}

//keep for one-off requests
Future<List> dbLink(String query) async {
  MySqlConnection conn =
      await MySqlConnection.connect(settings, isUnixSocket: true);
  final results = await conn.query(query);
  List<Map<String, dynamic>> rows = [];
  for (var row in results) {
    rows.add(row.fields);
  }
  conn.close();
  return rows;
}

Future<Response> _logedOutAndChangedPasswordHandler(
    Request request, String email) async {
  String userEmail = email;
  dbLink(
      "INSERT INTO enquiries VALUES ('$userEmail' , 'This user has reported a security issue. Someone tried to change their passwords.')");
  String currentDirectory = path.dirname(Platform.script.toFilePath());
  String htmlFilePath =
      path.join(currentDirectory, "assets/fraudulousPasswordReset.html");

  final htmlFile = File(htmlFilePath);
  if (await htmlFile.exists()) {
    final htmlContent = await htmlFile.readAsString();
    return Response.ok(htmlContent, headers: {'Content-Type': 'text/html'});
  } else {
    return Response.notFound('Page not found');
  }
}

String generateRandomPassword(int length) {
  const String chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  Random random = Random();
  String password = '';

  for (int i = 0; i < length; i++) {
    int index = random.nextInt(chars.length);
    password += chars[index];
  }

  return password;
}

Future<Response> _passwordChangeHandler(Request request) async {
  var value = await utf8.decodeStream(request.read());
  var decodedValue = jsonDecode(value);
  String token = decodedValue["token"];
  String newHash = decodedValue["password"];

  if (_isValidToken(token)) {
    JwtClaim claim = verifyJwtHS256Signature(token, Properties.jwtSecret);
    String? subject = claim.subject;
    MySqlConnection conn =
        await MySqlConnection.connect(settings, isUnixSocket: true);
    await conn
        .query('UPDATE users SET hash = ? WHERE email = ?', [newHash, subject]);
    conn.close();
    return Response.ok("Password changed");
  } else {
    return Response.notModified();
  }
}

void resetPassword(
    String hashPass, String email, String generatedHashPass) async {
  await Future.delayed(Duration(minutes: 10));
  MySqlConnection conn =
      await MySqlConnection.connect(settings, isUnixSocket: true);
  if (responseToList(await conn.query(
          'SELECT hash FROM users WHERE email = ?', [email]))[0]["hash"] ==
      generatedHashPass) {
    await conn
        .query('UPDATE users SET hash = ? WHERE email = ?', [hashPass, email]);
    print("password reset");
  }

  conn.close();
}

// Handler to send an email
Future<Response> _recoveryEmailHandler(Request request) async {
  var value = await utf8.decodeStream(request.read());
  var decodedValue = jsonDecode(value);
  String email = decodedValue['email'];
  // String subject = decodedValue['subject'];
  // String body = decodedValue['body'];
  // Check if the email is in the database
  final connection =
      await MySqlConnection.connect(settings, isUnixSocket: true);
  final results = await connection
      .query('SELECT * FROM emailList WHERE email = ?', [email]);
  if (results.isNotEmpty) {
    Map saltAndHashAndName = responseToList(await connection.query(
        'SELECT salt, hash, name FROM users WHERE email = ?', [email]))[0];
    final newTemporaryPass = generateRandomPassword(7);
    String generatedHashPass = sha256
        .convert(utf8.encode("${saltAndHashAndName['salt']}$newTemporaryPass"))
        .toString();
    await connection.query('UPDATE users SET hash = ? WHERE email = ?',
        [generatedHashPass, email]);
    resetPassword(saltAndHashAndName["hash"], email, generatedHashPass);

    Map<String, String> translations = {
      'en':
          "You seem to have forgotten your password. \n Here is a temporary password: $newTemporaryPass",
      'fr':
          "Il semble que vous ayez oublié votre mot de passe. \n Voici un mot de passe temporaire : $newTemporaryPass",
      'es':
          "Parece que has olvidado tu contraseña. \n Aquí tienes una contraseña temporal: $newTemporaryPass",
    };
    Map subjectTranslations = {
      "en": "Recover your Kapp account",
      "fr": "Récupérez votre compte Kapp",
      "es": "Recupera tu cuenta de Kapp"
    };

    String language = responseToList((await connection.query(
        'SELECT language FROM users WHERE email = ?', [email])))[0]["language"];
    connection.close();
//
    String currentDirectory = path.dirname(Platform.script.toFilePath());
    String htmlFilePath =
        path.join(currentDirectory, "assets/forgotPasswordEmail.html");
    String htmlContent = await File(htmlFilePath).readAsString();
    htmlContent = htmlContent.replaceAll('{yourNewPass}', newTemporaryPass);
    htmlContent = htmlContent.replaceAll('{name}', saltAndHashAndName['name']);
    htmlContent = htmlContent.replaceAll('{linkToPage}',
        "https://kappserver-c4sqysuqeq-od.a.run.app/api/changePasswordAndLogoutAllDevices/$email"); //to change

    final message = Message()
      ..from = Address('your_email@example.com')
      ..recipients.add(email)
      ..subject = subjectTranslations[language]
      ..text = translations[language]
      ..html = htmlContent;

    // Email exists in the database
    try {
      // Send the email
      final smtpServer = SmtpServer('smtp.gmail.com',
          username: 'kapp.kube.solutions@gmail.com',
          password: 'liin glad hxkr qzwc');
      await send(message, smtpServer);
      return Response.ok('Email sent');
    } catch (e) {
      return Response.internalServerError();
    }
  } else {
    // Email does not exist in the database
    connection.close();
    return Response.badRequest();
  }
}

Future<Response> _delHandler(Request request) async {
  var value = await utf8.decodeStream(request.read());
  var decodedValue = jsonDecode(value);
  MySqlConnection conn =
      await MySqlConnection.connect(settings, isUnixSocket: true);
  String token = decodedValue['token'];
  String user = decodedValue["user"];
  if (_isValidToken(token)) {
    JwtClaim claim = verifyJwtHS256Signature(token, Properties.jwtSecret);
    String? subject = claim.subject;
    if (subject == "yes@me.com") {
      const List tables = [
        "tools",
        "users",
        "emailList",
      ];
      for (String t in tables) {
        conn.query("DELETE FROM $t WHERE email = '$user'");
      }

      conn.close();
      return Response.ok("User deleted");
    } else {
      conn.close();
      return Response.forbidden("You're not allowed to that");
    }
  } else {
    conn.close();
    return Response.forbidden("You're not allowed to that");
  }
}

List responseToList(var results) {
  List<Map<String, dynamic>> rows = [];
  if (results.isEmpty) {
    return [];
  } else {
    for (var row in results) {
      rows.add(row.fields);
    }
  }

  return rows;
}

//translated tbt
Future<Response> _toolGetHandler(Request request, String id) async {
  var value = await utf8.decodeStream(request.read());
  var decodedValue = jsonDecode(value);
  MySqlConnection conn =
      await MySqlConnection.connect(settings, isUnixSocket: true);
  String token = decodedValue['token'];
  if (_isValidToken(token)) {
    JwtClaim claim = verifyJwtHS256Signature(token, Properties.jwtSecret);
    String? subject = claim.subject;

    // values = {
    //   "1234order": responseToList(
    //       await conn.query("SELECT * FROM order WHERE email = '$subject'"))[0]
    // };
    // List goals = responseToList(
    //     await conn.query("SELECT * FROM goals WHERE email = '$subject'"));
    // for (Map line in goals) {
    //   values.addAll({line["name"]: line});
    // }

    const List tables = ["perso", "risk", "goals", "pockets"];
    String table = tables[int.parse(id)];

    Map values = responseToList(await conn
        .query("SELECT $table FROM tools WHERE email = '$subject'"))[0];

    conn.close();
    return Response.ok(jsonEncode(values));
  } else {
    conn.close();
    return Response.forbidden("something went wrong");
  }
}

//translated tbt
Future<Response> _toolUpdateHandler(Request request, String id) async {
  var value = await utf8.decodeStream(request.read());
  var decodedValue = jsonDecode(value);
  String token = decodedValue['token'];
  Map updated = decodedValue['updated'];
  MySqlConnection conn =
      await MySqlConnection.connect(settings, isUnixSocket: true);
  if (_isValidToken(token)) {
    JwtClaim claim = verifyJwtHS256Signature(token, Properties.jwtSecret);
    String? subject = claim.subject;
    const List tables = ["perso", "risk", "goals", "pockets"];
    String table = tables[int.parse(id)];
    conn.query(
        "UPDATE tools SET $table = '${jsonEncode(updated)}' WHERE email = '$subject'");
    // userDB.userList[subject].toolValues[int.parse(id)] = updated;
    conn.close();
    return Response.ok("all good");
  } else {
    conn.close();
    return Response.forbidden("something went wrong");
  }
}

//translated but not completly and tbt
Future<Response> _userUpdateHandler(Request request) async {
  var value = await utf8.decodeStream(request.read());
  Map decodedValue = jsonDecode(value);
  String token = decodedValue['token'];

  if (_isValidToken(token)) {
    JwtClaim claim = verifyJwtHS256Signature(token, Properties.jwtSecret);
    String? subject = claim.subject;
    decodedValue.remove("token");
    MySqlConnection conn =
        await MySqlConnection.connect(settings, isUnixSocket: true);
    for (String key in decodedValue.keys) {
      value = decodedValue[key];
      // switch (key) {
      //   case "settings":
      //     conn.query(
      //         "UPDATE settings SET val0 = ${value[0]}, val1= ${value[1]} WHERE email = '$subject'");

      //   case "dicoUnlock":
      //     conn.query(
      //         "UPDATE dicoUnlock SET val0 = ${value[0]}, val1= ${value[1]}, val2 = ${value[2]}, val3 = ${value[3]}, val4 = ${value[4]}, val5 = ${value[5]}, val6 = ${value[6]}, val7 = ${value[7]}, val8 = ${value[8]}, val9 = ${value[9]}  WHERE email = '$subject'");
      //   case "stats":
      //     conn.query(
      //         "UPDATE stats SET val0 = ${value[0]}, val1= ${value[1]}, val2 = ${value[2]}, val3 = ${value[3]}, val4 = ${value[4]}, val5 = ${value[5]}, val6 = ${value[6]}, val7 = ${value[7]}, val8 = ${value[8]}, val9 = ${value[9]}, val10 = ${value[10]}, val11 = ${value[11]}, val12 = ${value[12]}  WHERE email = '$subject'");
      //   default:
      await conn
          .query("UPDATE users SET $key = '$value' WHERE email = '$subject'");
      // }
    }
    // userDB.userList[subject].updateUser(decodedValue);
    conn.close();
    return Response.ok("Update registered");
  } else {
    return Response.forbidden("no no no");
  }
}

// List enquiries = [];
//translated tested and validated
Future<Response> _contactUsHandler(Request request) async {
  var value = await utf8.decodeStream(request.read());
  String id = jsonDecode(value)['id'];
  String message = jsonDecode(value)['message'];

  dbLink("INSERT INTO enquiries VALUES ('$id' , '$message')");
  // enquiries.add([message, id]);
  return Response.ok("Message received");
}

//translated
Future<Response> _initLogHandler(Request request) async {
  var value = await utf8.decodeStream(request.read());
  String email = jsonDecode(value)['email'];
  MySqlConnection conn =
      await MySqlConnection.connect(settings, isUnixSocket: true);

  var results =
      await conn.query("SELECT * FROM emailList WHERE email = '$email';");
  List rows = responseToList(results);
  if (rows != []) {
    var results =
        await conn.query("SELECT salt FROM users WHERE email = '$email';");
    List info = responseToList(results);
    String salt = info[0]["salt"];
    conn.close();
    return Response.ok(jsonEncode(salt));
  } else {
    return Response(404);
  }

  //changed
  // userDB.updateEmailList();
  // if (userDB.emailList.contains(email)) {
  //   return Response.ok(jsonEncode(userDB.userList[email].salt), headers: {
  //     ..._jsonHeaders,
  //     'Cache-Control': 'public, max-age=604800, immutable',
  //   });
  // } else {
  //   return Response(404);
  // }
}

//translated
Future<Response> _tokenLog(Request request) async {
  var value = await utf8.decodeStream(request.read());
  String token = jsonDecode(value)['token'];
  MySqlConnection conn =
      await MySqlConnection.connect(settings, isUnixSocket: true);
  if (_isValidToken(token)) {
    JwtClaim claim = verifyJwtHS256Signature(token, Properties.jwtSecret);
    String? subject = claim.subject;
    List info1 = responseToList(await conn.query(
        "SELECT email, name, token, exP, level, language, theoreticalLevel, progress, stats, dicoUnlock, settings, tag, avatar FROM users WHERE email='$subject';")); //problem between XP and exP notations
    // List stats = responseToList(
    //     await conn.query("SELECT * FROM stats WHERE email = '$subject';"));
    // List dicoUnlock = responseToList(
    //     await conn.query("SELECT * FROM dicoUnlock WHERE email = '$subject';"));
    // List settings = responseToList(
    //     await conn.query("SELECT * FROM settings WHERE email = '$subject';"));

    // info1[0].addAll(
    //     {"stats": stats[0], "dico": dicoUnlock[0], "settings": settings[0]});
    conn.close();
    return Response.ok(jsonEncode(info1[0]), headers: {
      ..._jsonHeaders,
      'Cache-Control': 'public, max-age=604800, immutable',
    });
  } else {
    conn.close();
    return Response.forbidden("no no no");
  }
}

bool _isValidToken(String token) {
  const key = Properties.jwtSecret;
  try {
    verifyJwtHS256Signature(token, key);
    return true;
  } on JwtException {
    print('invalid token');
  }
  return false;
}

//translated  tbt
Future<Response> _customerHandler(Request request) async {
  var value = await utf8.decodeStream(request.read());
  Map<String, dynamic> customer = jsonDecode(value)['customer'];
  int tag = Random().nextInt(9000) + 1000;
  //okay lets try again
  String email = customer["email"];
  String name = customer["name"];
  String currentDirectory = path.dirname(Platform.script.toFilePath());
  print(currentDirectory);
  String htmlFilePath =
      path.join(currentDirectory, "assets/welcomeEmailEn.html");
  print(htmlFilePath);
  final htmlFile = await File(htmlFilePath).readAsString();
  var htmlContent = htmlFile.replaceAll('{name}', name);
  print(htmlContent);

  String text =
      "Welcome $name!\n Thank you for joining us in the world of finance.\n Here you're going to learn everything you need to know about personal finance, and we'll also give you the tools to apply what you learn \n 2024 Kapp Personal Finance. All rights reserved.";
  final message = Message()
    ..from = Address('your_email@example.com')
    ..recipients.add(email)
    ..subject = "Welcome to Kapp!"
    ..text = text
    ..html = htmlContent;
  print(message.subject);
  try {
    // Send the email
    final smtpServer = SmtpServer('smtp.gmail.com',
        username: 'kapp.kube.solutions@gmail.com',
        password: 'liin glad hxkr qzwc');
    await send(message, smtpServer);
  } catch (e) {
    print(e);
  }
  //end of weird shit

  MySqlConnection conn =
      await MySqlConnection.connect(settings, isUnixSocket: true);
  try {
    await conn.query(
        "INSERT INTO users VALUES ('${customer["email"]}','${customer["name"]}','${User.signToken(customer["email"])}','${customer["password"]}','${customer["salt"]}','${customer["language"]}','1','0','1','1','${jsonEncode([
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0
        ])}', '${jsonEncode([
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          100,
          0,
          0
        ])}', '${jsonEncode([
          0,
          1
        ])}', '$tag', '00#00#00#00#00#00');"); //adds tag and default avatar
    await conn.query("INSERT INTO emailList VALUES ('${customer["email"]}');");
    // await conn.query(
    //     "INSERT INTO dicoUnlock VALUES ('${customer["email"]}', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0');");
    // await conn.query(
    //     "INSERT INTO settings VALUES ('${customer["email"]}', '0', '1');");
    // await conn.query(
    //     "INSERT INTO stats VALUES ('${customer["email"]}', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '100', '0', '0');");
    var myPerso = jsonEncode({
      "age": "2003",
      "career": 0,
      "time": 1.0,
      "dependent": true,
      "netWorth": "1",
      "level": 0,
      "expenses": "1",
      "risk": 0,
      "approach": 0,
      "handsOn": 0,
      "interest": 0,
      "preferences": 0,
      "limitations": false,
      "strategy": 0,
    });
    var myGoals = jsonEncode({
      '1234order': [],
    });
    var risk = jsonEncode({});
    var pockets = jsonEncode({
      "Protect": {
        "name": "Base",
        "allocations": [90, 10],
        "investements": ["Hard", "Cash"],
        "totalAllocated": 10000
      },
      "Maintain": {
        "name": "Risky",
        "allocations": [66, 33],
        "investements": ["Equity", "Bond"],
        "totalAllocated": 10000
      },
      "Inhance": {
        "name": "Medium",
        "allocations": [20, 20, 20, 20, 20],
        "investements": [
          "Single Stock",
          "Derivatives",
          "VC",
          "Private Equity",
          "Hedge Fund"
        ],
        "totalAllocated": 10000
      },
      "portofolioValues": [30.0, 48.0, 22.0]
    });
    await conn.query(
        "INSERT INTO tools VALUES ('${customer["email"]}', '$myPerso', '$risk', '$myGoals', '$pockets')");

    //send welcome email
    //worse code to ever exist I hate it so much

    // print("here");
    // String htmlContent = "";
    // try {
    //   print("wtf is gonning on");

    //
    //   if (await htmlFile.exists()) {
    //     htmlContent = await htmlFile.readAsString();
    //     print("im gonna kill myself");

    //
    //     print("how about now");
    //   } else {
    //     return Response.notFound('Page not found');
    //   }
    // } catch (e) {
    //   print(e);
    // }

    // print("there");

    // // Email exists in the database
  } on Exception {
    conn.close();
    return Response.forbidden("user already exists");
  }
  // userDB.addUser(customer);
  conn.close();
  return Response.ok("Customer signed up successfully");
}

UserDB userDB = UserDB();

//translated tbt
Future<Response> _authHandler(Request request) async {
  var value = await utf8.decodeStream(request.read());
  Map decodedValue = jsonDecode(value);
  String subject = decodedValue["email"];
  MySqlConnection conn =
      await MySqlConnection.connect(settings, isUnixSocket: true);
  List user = responseToList(
      await conn.query("SELECT * FROM emailList WHERE email = '$subject';"));
  if (user.isNotEmpty) {
    List pass = responseToList(
        await conn.query("SELECT hash FROM users WHERE email = '$subject';"));
    if (pass[0]["hash"] == decodedValue["password"]) {
      List info1 = responseToList(await conn.query(
          "SELECT email, name, token, exP, level, language, theoreticalLevel, progress, stats, dicoUnlock, settings, tag, avatar FROM users WHERE email='$subject';")); //problem between XP and exP notations
      // List stats = responseToList(
      //     await conn.query("SELECT * FROM stats WHERE email = '$subject';"));
      // List dicoUnlock = responseToList(await conn
      //     .query("SELECT * FROM dicoUnlock WHERE email = '$subject';"));
      // List settings = responseToList(
      //     await conn.query("SELECT * FROM settings WHERE email = '$subject';"));

      // info1[0].addAll(
      //     {"stats": stats[0], "dico": dicoUnlock[0], "settings": settings[0]});
      conn.close();
      return Response.ok(jsonEncode(info1[0]), headers: {
        ..._jsonHeaders,
        'Cache-Control': 'public, max-age=604800, immutable',
      });
    } else {
      conn.close();
      return Response.notFound('Wrong password');
    }
  } else {
    conn.close();
    return Response.notFound("no user found");
  }
}

LessonDB lessonDB = LessonDB();

//translated
Future<Response> _lessonHandler(Request request, String b, String lng) async {
  final lessonNum = int.parse(b);
  final language = lng;
  //
  String currentDirectory = path.dirname(Platform.script.toFilePath());
  String filePath = path.join(currentDirectory,
      "assets/${lessonDB.lessonList[lessonNum]}_$language.txt");
  //
  final lesson = File(filePath);
  List<String> lines = await lesson
      .openRead()
      .transform(utf8.decoder) // Decode bytes to UTF-8.
      .transform(LineSplitter())
      .toList();
  // List<String> images = [
  //   for (String thisPath in lessonDB.imageList[chapter][lessonNum])
  //     base64Encode(
  //         await File(path.join(currentDirectory, "assets/$thisPath.png"))
  //             .readAsBytes())
  // ];
  return Response.ok(_jsonEncode({'lesson': lines}), headers: {
    ..._jsonHeaders,
    'Cache-Control': 'public, max-age=604800, immutable',
  });
}

Future<Response> _imagesHandler(Request request, String b, String lng) async {
  final lessonNum = int.parse(b);
  //not using language for now
  //

  // String currentDirectory = path.dirname(Platform.script.toFilePath());
  List<String> images = [
    for (String thisPath in lessonDB.imageList[lessonNum])
      base64Encode(await StorageBucket.getPic(thisPath))
    //     base64Encode(
    // await File(path.join(currentDirectory, "assets/$thisPath.png"))
    //     .readAsBytes())
  ];
  return Response.ok(_jsonEncode({'images': images}), headers: {
    ..._jsonHeaders,
    'Cache-Control': 'public, max-age=604800, immutable',
  });
}

//not translated
Future<Response> _quizHandler(Request request, String a, String lng) async {
  // final refNumber = a;
  // final language = lng;
  // final quiz = File(path);
  final quiz = [
    {
      'question': 'What is the capital of France?',
      'answers': ['Paris', 'London', 'Berlin', 'Rome'],
      'correctAnswerIndex': 0,
    },
    {
      'question': 'What is 2 + 2?',
      'answers': ['3', '4', '5', '6'],
      'correctAnswerIndex': 1,
    },
    {
      'question': 'Which planet is known as the Red Planet?',
      'answers': ['Jupiter', 'Venus', 'Mars', 'Saturn'],
      'correctAnswerIndex': 2,
    },
  ];
  return Response.ok(json.encode(quiz));
}

String _jsonEncode(Object? data) =>
    const JsonEncoder.withIndent(' ').convert(data);

const _jsonHeaders = {
  'content-type': 'application/json',
};

final _watch = Stopwatch();
