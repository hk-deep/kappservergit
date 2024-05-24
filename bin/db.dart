import 'user_element.dart';

class LessonDB {
  List lessonList = [
    "lesson",
    "lesson",
    "lesson",
    "lesson",
    "lesson",
    "lesson",
  ];

  List imageList = [
    [
      "thumbsUp",
      "thumbsUp",
    ],
    [
      "thumbsUp",
      "thumbsUp",
    ],
    [
      "thumbsUp",
      "thumbsUp",
    ],
    [
      "thumbsUp",
      "thumbsUp",
    ],
    [
      "thumbsUp",
      "thumbsUp",
    ],
    [
      "thumbsUp",
      "thumbsUp",
    ],
  ];
}

class UserDB {
  Map userList = {
    "yes@me.com": User(
        email: "yes@me.com",
        name: "me",
        token:
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3MDg3NTM2NjMsImlhdCI6MTcwODcxMDQ2MywiaXNzIjoiRGFydCBTZXJ2ZXIiLCJzdWIiOiJ5ZXNAbWUuY29tIn0.o15WDzXt4voMYQLsRHMtFYPBpOuNsC0-61kQb18_4Lk",
        password:
            "3a96f8f130eb64783f59f32bc8e2abd7c975c5cd18e23caa5b734ee349c1dd71",
        salt: "kjdjd",
        listOfchapterStatus: [
          [5, 5, 5, 0, 0, 0, 0, 0],
          [5, 2, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0, 0, 0]
        ],
        theoreticalLevel: 2,
        exP: 4999,
        level: 4,
        language: "en",
        progress: 5,
        settings: [1, 1],
        stats: [72, 1, 1, 1, 1, 0, 56, 5, 32, 95, 12, 100, 69, 69],
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
            "strategy": "None",

            //first tool default values
          },
          {},
          {
            "1234order": ["goal 1", "goal 2", "goal 3", "goal 4"],
            "goal 1": {
              "name": "goal 1",
              "goalType": "Retirement",
              "timeHorizon": "15",
              "targetAmount": 10000,
              "initialInvestement": 1000,
              "monthlyAddon": 200,
            },
            "goal 4": {
              "name": "goal 4",
              "goalType": "Funding education",
              "timeHorizon": "15",
              "targetAmount": 10000,
              "initialInvestement": 1000,
              "monthlyAddon": 200,
            },
            "goal 2": {
              "name": "goal 2",
              "goalType": "Building wealth",
              "timeHorizon": "15",
              "targetAmount": 10000,
              "initialInvestement": 1000,
              "monthlyAddon": 200,
            },
            "goal 3": {
              "name": "goal 3",
              "goalType": "Building wealth",
              "timeHorizon": "15",
              "targetAmount": 10000,
              "initialInvestement": 1000,
              "monthlyAddon": 200,
            },
          }
        ],
        dicoUnlock: [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1])
  };

  List emailList = [];
  void updateEmailList() {
    emailList = userList.keys.toList();
  }

  void addUser(Map<String, dynamic> customer) {
    User user = User.fromDynamicMap(customer);
    userList[customer['email']] = user;
  }
}
