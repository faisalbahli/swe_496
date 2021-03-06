import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:swe496/controllers/UserControllers/userController.dart';
import 'package:swe496/models/Activity.dart';
import 'package:swe496/models/Chat.dart';
import 'package:swe496/models/Event.dart';
import 'package:swe496/models/Members.dart';
import 'package:swe496/models/Message.dart';
import 'package:swe496/models/Project.dart';
import 'package:swe496/models/TaskOfProject.dart';
import 'package:uuid/uuid.dart';

class ProjectCollection {
  final Firestore _firestore = Firestore.instance;

  Future<bool> createNewProject(
      String projectName, List<String> membersToBeAdded) async {
    String projectID =
        Uuid().v1(); // Project ID, UuiD is package that generates random ID.

    UserController userController = Get.find<UserController>();
    // Add the creator of the project to the members list and assign him as admin.
    var member = Member(
      memberUID: userController.user.userID,
      isAdmin: true,
    );
    List<Member> membersList = new List();
    membersList.add(member);

    // Add the rest members of the project to the members list.

    membersToBeAdded.forEach((memberUID) {
      var member = Member(
        memberUID: memberUID,
        isAdmin: false, // Not admins
      );
      membersList.add(member);
    });

    // Save his ID in the membersUIDs list
    List<String> membersIDs = new List();
    membersIDs.add(userController.user.userID);

    // Save the id of the other members
    membersIDs.addAll(membersToBeAdded);

    List<TaskOfProject> listOfTasks = new List();
    // Create chat for the new project
    var chat = Chat(chatID: projectID);

    // Create the project object
    var newProject = Project(
      projectID: projectID,
      projectName: projectName,
      image: '',
      joiningLink: '$projectID',
      isJoiningLinkEnabled: true,
      pinnedMessage: '',
      chat: chat,
      members: membersList,
      membersIDs: membersIDs,
      task: listOfTasks,
    );

    // Add the new project ID to the user's project list.
    userController.user.userProjectsIDs.add(projectID);
    // Add the new chat ID to the user's chat list.
    userController.user.userChatsIDs.add(projectID);

    try {
      // Convert the project object to be a JSON.
      var jsonUser = userController.user.toJson();
      // add the project chat to the chats collection
      Map<String, dynamic> chatInfo = new Map<String, dynamic>();
      chatInfo['GroupName'] = projectName;
      chatInfo['LastMsg'] = "";
      chatInfo['membersIDs'] = membersIDs;
      chatInfo['type'] = 'group';
      Firestore.instance
          .collection('Chats')
          .document(projectID)
          .setData(chatInfo);
      // Send the user JSON data to the fire base.
      await Firestore.instance
          .collection('userProfile')
          .document(userController.user.userID)
          .setData(jsonUser);

      // Add the project to other members.
      addProjectIDInMembersProfile(projectID, membersIDs);
      //add the chat id to other members
      addChatIDInMembersProfile(projectID, membersIDs);
      // Convert the project object to be a JSON.
      var jsonProject = newProject.toJson();

      // Send the project JSON data to the fire base.
      await Firestore.instance
          .collection('projects')
          .document(projectID)
          .setData(jsonProject);

      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<void> addProjectIDInMembersProfile(
      String projectID, List<String> membersIDs) async {
    try {
      for (int i = 0; i < membersIDs.length; i++) {
        await Firestore.instance
            .collection('userProfile')
            .document(membersIDs[i])
            .updateData(({
              'userProjectsIDs': FieldValue.arrayUnion([projectID]),
            }));
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> addChatIDInMembersProfile(
      String projectID, List<String> membersIDs) async {
    try {
      for (int i = 0; i < membersIDs.length; i++) {
        await Firestore.instance
            .collection('userProfile')
            .document(membersIDs[i])
            .updateData(({
              'userChatsIDs': FieldValue.arrayUnion([projectID]),
            }));
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> addNewMembersToProject(
      String projectID, List<String> membersToBeAdded) async {
    List<Member> membersList = new List();

    // Add the rest members of the project to the members list.

    membersToBeAdded.forEach((memberUID) {
      var member = Member(
        memberUID: memberUID,
        isAdmin: false, // Not admins
      );
      membersList.add(member);
    });

    // Save the id of the other members
    List<String> membersIDs = new List();
    membersIDs.addAll(membersToBeAdded);

    try {
      DocumentReference documentReference =
          _firestore.collection('projects').document(projectID);

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(documentReference);
        if (!snapshot.exists) {
          throw Exception("data does not exist!");
        }

        for (int i = 0; i < membersList.length; i++) {
          await transaction.update(
            documentReference,
            {
              'members': FieldValue.arrayUnion([membersList[i].toJson()])
            },
          );
          await addProjectToUserProfile(projectID, membersList[i].memberUID);
        }
        await transaction.update(
          documentReference,
          {'membersIDs': FieldValue.arrayUnion(membersIDs)},
        );
      });
    } on Exception catch (e) {
      print(e);
    }
  }

  Future<void> addProjectToUserProfile(
      String projectID, String memberID) async {
    try {
      DocumentReference documentReference =
          _firestore.collection('userProfile').document(memberID);

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(documentReference);
        if (!snapshot.exists) {
          throw Exception("data does not exist!");
        }

        await transaction.update(
          documentReference,
          {
            'userProjectsIDs': FieldValue.arrayUnion([projectID]),
            // add chat also
            'userChatsIDs': FieldValue.arrayUnion([projectID])
          },
        );
      });
    } on Exception catch (e) {
      print(e);
    }
  }

  Future<void> removeMemberFromProject(
      String projectID, String memberID, bool isAdmin) async {
    var memberToBeRemoved = new Member(isAdmin: isAdmin, memberUID: memberID);

    // Convert the member object to JSON
    var oldMemberJson = memberToBeRemoved.toJson();

    removeProjectFromUserProfile(projectID, memberID);

    try {
      DocumentReference documentReference =
          _firestore.collection('projects').document(projectID);

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(documentReference);
        if (!snapshot.exists) {
          throw Exception("data does not exist!");
        }

        await transaction.update(
          documentReference,
          {
            'members': FieldValue.arrayRemove([oldMemberJson])
          },
        );

        await transaction.update(
          documentReference,
          {
            'membersIDs': FieldValue.arrayRemove([memberID])
          },
        );
      });
    } on Exception catch (e) {
      print(e);
    }
  }

  Future<void> removeProjectFromUserProfile(
      String projectID, String memberID) async {
    try {
      DocumentReference documentReference =
          _firestore.collection('userProfile').document(memberID);

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(documentReference);
        if (!snapshot.exists) {
          throw Exception("data does not exist!");
        }

        await transaction.update(
          documentReference,
          {
            'userProjectsIDs': FieldValue.arrayRemove([projectID]),
            // chat also
            'userChatsIDs': FieldValue.arrayRemove([projectID]),
          },
        );
      });
    } on Exception catch (e) {
      print(e);
    }
  }

  Future<void> changeMemberRole(
      String projectID, String memberID, bool isCurrentMemberIsAdmin) async {
    // Creating the old member object for the project

    var oldMemberState =
        new Member(isAdmin: isCurrentMemberIsAdmin, memberUID: memberID);

    // Convert the old member object to JSON
    var oldMemberJson = oldMemberState.toJson();

    var newMemberState =
        new Member(isAdmin: !isCurrentMemberIsAdmin, memberUID: memberID);

    // Convert the new member object to JSON
    var newMemberJson = newMemberState.toJson();

    try {
      DocumentReference documentReference =
          _firestore.collection('projects').document(projectID);

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(documentReference);
        if (!snapshot.exists) {
          throw Exception("data does not exist!");
        }

        await transaction.update(
          documentReference,
          {
            'members': FieldValue.arrayRemove([oldMemberJson])
          },
        );

        await transaction.update(
          documentReference,
          {
            'members': FieldValue.arrayUnion([newMemberJson])
          },
        );
      });
    } on Exception catch (e) {
      print(e);
    }
  }

  Future<void> createNewTask(
      String projectID,
      String _taskName,
      String _taskDescription,
      String _taskStartDate,
      String _taskDueDate,
      String _taskPriority,
      String _taskAssignedTo,
      String _taskAssignedBy,
      String _taskStatus) async {
    // Record this action in the activity log of the project
    insertIntoActivityLog(projectID, "Created new task '$_taskName'");

    String taskID =
        Uuid().v1(); // Task ID, UuiD is package that generates random ID.

    // Creating a list of sub tasks for that task.
    List<TaskOfProject> subTasksList = new List();

    // Creating a list of messages/comment for that task.
    List<Message> messagesList = new List();

    // Splitting the username and the ID by (,)
    List listOfUserNameAndID = _taskAssignedTo.split(',');

    // Creating the task object for the project
    TaskOfProject taskOfProject = new TaskOfProject(
      taskID: taskID,
      taskName: _taskName,
      taskDescription: _taskDescription,
      startDate: _taskStartDate,
      dueDate: _taskDueDate,
      taskPriority: _taskPriority,
      isAssigned: _taskAssignedTo.isEmpty ? 'false' : 'true',
      // Determine if the task is assigned or not.
      assignedTo: _taskAssignedTo.isEmpty ? '' : listOfUserNameAndID[1],
      // Storing only the user ID
      assignedBy: _taskAssignedBy,
      taskStatus: _taskStatus,
      subtask: subTasksList,
      message: messagesList,
      isUpdatedByLeader: true,
      isUpdatedByAssignedMember: false,
    );

    // Creating the list of tasks for that project.
    List<TaskOfProject> listOfTasks = new List();

    // Adding the task to the list of tasks
    listOfTasks.add(taskOfProject);

    // Convert the task object to JSON
    try {
      var listOfTasksJson = taskOfProject.toJson();

      print(listOfTasksJson);

      return await _firestore
          .collection('projects')
          .document(projectID)
          .collection('tasks')
          .document(taskID)
          .setData(listOfTasksJson);
    } on Exception catch (e) {
      print(e);
    }
  }

  Stream<List<Project>> projectsListStream(String userID) {
    return Firestore.instance
        .collection('projects')
        .where('membersIDs', arrayContains: userID)
        .snapshots()
        .map((QuerySnapshot query) {
      List<Project> retVal = List();
      query.documents.forEach((element) {
        retVal.add(Project.fromJson(element.data));
      });
      return retVal;
    });
  }

  Stream<Project> projectStream(String projectID) {
    return _firestore
        .collection('projects')
        .document(projectID)
        .snapshots()
        .map((DocumentSnapshot documentSnapshot) {
      if (documentSnapshot.data == null) {
        return null;
      }
      return Project.fromJson(documentSnapshot.data);
    });
  }

  Future<void> createNewSubtask(
      String projectID,
      String mainTaskID,
      String _subtaskName,
      String _subtaskDescription,
      String _subtaskStartDate,
      String _subtaskDueDate,
      String _subtaskPriority,
      String _subtaskStatus) async {
    // Record this action in the activity log of the project
    insertIntoActivityLog(projectID, "Created new subtask '$_subtaskName'");

    String subtaskID =
        Uuid().v1(); // Task ID, UuiD is package that generates random ID.

    // Creating the task object for the project
    TaskOfProject newSubtaskOfProject = new TaskOfProject(
      taskID: subtaskID,
      taskName: _subtaskName,
      taskDescription: _subtaskDescription,
      startDate: _subtaskStartDate,
      dueDate: _subtaskDueDate,
      taskPriority: _subtaskPriority,
      taskStatus: _subtaskStatus,
      isAssigned: 'true',
    );
    // Convert the sub task object to JSON
    var newSubtaskJSON = newSubtaskOfProject.toJson();
    try {
      _firestore
          .collection('projects')
          .document(projectID)
          .collection('tasks')
          .document(mainTaskID)
          .setData(
              ({
                'subTask': FieldValue.arrayUnion([
                  newSubtaskJSON,
                ]),
              }),
              merge: true);
      updateTaskNotificationByLeader(projectID, mainTaskID);
    } on Exception catch (e) {
      print(e);
    }
  }

  Future<void> editTask(
      String projectID,
      String taskID,
      String taskName,
      String taskDescription,
      String startDate,
      String dueDate,
      String taskPriority,
      String assignedTo) async {
    // Record this action in the activity log of the project
    insertIntoActivityLog(projectID, "Updated a task '$taskName'");

    List listOfUserNameAndID = assignedTo.split(',');

    try {
      _firestore
          .collection('projects')
          .document(projectID)
          .collection('tasks')
          .document(taskID)
          .setData(
              ({
                "taskName": taskName,
                "taskDescription": taskDescription,
                "startDate": startDate,
                "dueDate": dueDate,
                "taskPriority": taskPriority,
                "assignedTo": assignedTo.isEmpty ? '' : listOfUserNameAndID[1],
                "isAssigned": assignedTo.isEmpty ? 'false' : 'true',
                "taskStatus": 'Not-started',
                "isUpdatedByLeader": true,
                "isUpdatedByAssignedMember": false,
              }),
              merge: true);

      Get.back();
      Get.snackbar('Success', "Task '$taskName' has been updated successfully");
    } on Exception catch (e) {
      print(e);
    }
  }

  Future<void> updateTaskNotificationByLeader(
    String projectID,
    String taskID,
  ) async {
    try {
      _firestore
          .collection('projects')
          .document(projectID)
          .collection('tasks')
          .document(taskID)
          .setData(
              ({
                "isUpdatedByLeader": true,
                "isUpdatedByAssignedMember": false,
              }),
              merge: true);
    } on Exception catch (e) {
      print(e);
    }
  }

  Future<void> updateTaskNotificationByAssignedMember(
    String projectID,
    String taskID,
  ) async {
    try {
      _firestore
          .collection('projects')
          .document(projectID)
          .collection('tasks')
          .document(taskID)
          .setData(
              ({
                "isUpdatedByLeader": false,
                "isUpdatedByAssignedMember": true,
              }),
              merge: true);
    } on Exception catch (e) {
      print(e);
    }
  }

  Future<void> readNotificationByAssignedMember(
    String projectID,
    String taskID,
  ) async {
    try {
      _firestore
          .collection('projects')
          .document(projectID)
          .collection('tasks')
          .document(taskID)
          .setData(
              ({
                "isUpdatedByLeader": false,
              }),
              merge: true);
    } on Exception catch (e) {
      print(e);
    }
  }

  Future<void> readNotificationByLeader(
    String projectID,
    String taskID,
  ) async {
    try {
      _firestore
          .collection('projects')
          .document(projectID)
          .collection('tasks')
          .document(taskID)
          .setData(
              ({
                "isUpdatedByAssignedMember": false,
              }),
              merge: true);
    } on Exception catch (e) {
      print(e);
    }
  }

  Future<void> deleteTask(
    String projectID,
    String taskID,
  ) async {
    // Record this action in the activity log of the project
    insertIntoActivityLog(projectID, "Deleted a task");

    try {
      _firestore
          .collection('projects')
          .document(projectID)
          .collection('tasks')
          .document(taskID)
          .delete();
    } on Exception catch (e) {
      print(e);
    }
  }

  Future<void> deleteSubtask(
      String projectID,
      String taskID,
      String subtaskID,
      String subtaskName,
      String subtaskDescription,
      String startDate,
      String dueDate,
      String subtaskPriority,
      String subtaskStatus) async {
    // Record this action in the activity log of the project
    insertIntoActivityLog(projectID, "Deleted a subtask '$subtaskName'");

    // Creating the task object for the project

    TaskOfProject deletedSubtaskOfProject = new TaskOfProject(
      taskID: subtaskID,
      taskName: subtaskName,
      taskDescription: subtaskDescription,
      startDate: startDate,
      dueDate: dueDate,
      taskPriority: subtaskPriority,
      taskStatus: subtaskStatus,
      isAssigned: 'true',
      assignedBy: null,
      assignedTo: null,
    );
    // Convert the sub task object to JSON
    var deletedSubtaskJSON = deletedSubtaskOfProject.toJson();

    try {
      _firestore
          .collection('projects')
          .document(projectID)
          .collection('tasks')
          .document(taskID)
          .setData({
        'subTask': FieldValue.arrayRemove([deletedSubtaskJSON])
      }, merge: true);
    } on Exception catch (e) {
      print(e);
    }
  }

  Future<void> editSubtask(
      String projectID,
      String taskID,
      String subtaskID,
      String subtaskName,
      String subtaskDescription,
      String startDate,
      String dueDate,
      String subtaskPriority,
      String oldSubtaskName,
      String oldSubtaskDescription,
      String oldStartDate,
      String oldDueDate,
      String oldSubtaskPriority,
      String subtaskStatus) async {
    // Record this action in the activity log of the project
    insertIntoActivityLog(projectID, "Updated a subtask '$subtaskName'");

    await deleteSubtask(
            projectID,
            taskID,
            subtaskID,
            oldSubtaskName,
            oldSubtaskDescription,
            oldStartDate,
            oldDueDate,
            oldSubtaskPriority,
            subtaskStatus)
        .then((value) async {
      await createNewSubtask(projectID, taskID, subtaskName, subtaskDescription,
          startDate, dueDate, subtaskPriority, 'Not-Started');
    });

    updateTaskNotificationByLeader(projectID, taskID);
    Get.back();
    Get.snackbar(
        'Success', "Subtask '$subtaskName' has been updated successfully");
  }

  Future<void> createNewEvent(
      String projectID,
      String eventName,
      String eventDescription,
      String startDate,
      String endDate,
      String location) async {
    // Record this action in the activity log of the project
    insertIntoActivityLog(projectID, "Created new event '$eventName'");

    String eventID =
        Uuid().v1(); // Event ID, UuiD is package that generates random ID.

    Event event = new Event(
      eventID: eventID,
      eventName: eventName.trim(),
      eventDescription: eventDescription,
      eventStartDate: startDate,
      eventEndDate: endDate,
      eventLocation: location,
    );

    try {
      var eventJson = event.toJson();

      return await _firestore
          .collection('projects')
          .document(projectID)
          .collection('events')
          .document(eventID)
          .setData(eventJson);
    } on Exception catch (e) {
      print(e);
    }
  }

  Future<bool> editEvent(
      String projectID,
      String eventID,
      String eventName,
      String eventDescription,
      String startDate,
      String endDate,
      String location) async {
    // Record this action in the activity log of the project
    insertIntoActivityLog(projectID, "Updated an event '$eventName'");

    try {
      _firestore
          .collection('projects')
          .document(projectID)
          .collection('events')
          .document(eventID)
          .setData(
              ({
                "eventName": eventName,
                "eventDescription": eventDescription,
                "eventStartDate": startDate,
                "eventEndDate": endDate,
                "eventLocation": location,
              }),
              merge: true);

      return true;
    } on Exception catch (e) {
      print(e);
      return false;
    }
  }

  Future<void> deleteEvent(String projectID, String eventID) async {
    // Record this action in the activity log of the project
    insertIntoActivityLog(projectID, 'Deleted an event');

    try {
      _firestore
          .collection('projects')
          .document(projectID)
          .collection('events')
          .document(eventID)
          .delete();
    } on Exception catch (e) {
      print(e);
    }
  }

  // To view the tasks in the "tasks & events" tab for the admin.
  Stream<List<TaskOfProject>> getTasksOfProjectAssignedByAdmin(
      String projectID, String assignedBy) {
    return _firestore
        .collection('projects')
        .document(projectID)
        .collection('tasks')
        .where('assignedBy', isEqualTo: assignedBy)
        .snapshots()
        .map((QuerySnapshot query) {
      List<TaskOfProject> retVal = List();
      query.documents.forEach((element) {
        retVal.add(TaskOfProject.fromJson(element.data));
      });
      return retVal;
    });
  }

  // To view the tasks in the "tasks & events" tab for the assigned member.
  Stream<List<TaskOfProject>> getTasksOfProjectAssignedToMember(
      String projectID, String assignedTo) {
    return _firestore
        .collection('projects')
        .document(projectID)
        .collection('tasks')
        .where('assignedTo', isEqualTo: assignedTo)
        .snapshots()
        .map((QuerySnapshot query) {
      List<TaskOfProject> retVal = List();
      query.documents.forEach((element) {
        retVal.add(TaskOfProject.fromJson(element.data));
      });
      return retVal;
    });
  }

  Stream<List<Event>> getEventsOfProject(String projectID) {
    return _firestore
        .collection('projects')
        .document(projectID)
        .collection('events')
        .snapshots()
        .map((QuerySnapshot query) {
      List<Event> retVal = List();
      query.documents.forEach((element) {
        retVal.add(Event.fromJson(element.data));
      });
      return retVal;
    });
  }

  // To view the task details in TaskView.dart
  Stream<List<TaskOfProject>> taskStream(String projectID, String taskID) {
    return _firestore
        .collection('projects')
        .document(projectID)
        .collection('tasks')
        .where('taskID', isEqualTo: taskID)
        .snapshots()
        .map((QuerySnapshot query) {
      List<TaskOfProject> retVal = List();
      query.documents.forEach((element) {
        retVal.add(TaskOfProject.fromJson(element.data));
      });
      return retVal;
    });
  }

  Stream<Event> eventStream(String projectID, String eventID) {
    return _firestore
        .collection('projects')
        .document(projectID)
        .collection('events')
        .document(eventID)
        .snapshots()
        .map((DocumentSnapshot documentSnapshot) {
      if (documentSnapshot.data == null) {
        return null;
      }
      return Event.fromJson(documentSnapshot.data);
    });
  }

  Future<void> addCommentToTask(String projectID, String taskID,
      String senderID, String from, String contentOfMessage) async {
    insertIntoActivityLog(projectID, 'Added comment to task');

    Message message = new Message(
        messageID: Uuid().v1(),
        senderID: senderID,
        from: from,
        contentOfMessage: contentOfMessage,
        time: Timestamp.now());

    var jsonMessage = message.toJson();

    try {
      _firestore
          .collection('projects')
          .document(projectID)
          .collection('tasks')
          .document(taskID)
          .setData(
              ({
                'message': FieldValue.arrayUnion([
                  jsonMessage,
                ]),
              }),
              merge: true);

    } on Exception catch (e) {
      print(e);
    }
  }

  Future<void> updateProjectSettings(String projectID, String projectName,
      String pinnedMessage, bool joiningLinkStatus) async {
    try {
      _firestore.collection('projects').document(projectID).setData(
          ({
            'projectName': projectName,
            'pinnedMessage': pinnedMessage,
            'isJoiningLinkEnabled': joiningLinkStatus
          }),
          merge: true);
    } on Exception catch (e) {
      print(e);
    }
  }

  Future<void> insertIntoActivityLog(
      String projectID, String typeOfAction) async {
    String activityID =
        Uuid().v1(); // Activity ID, UuiD is package that generates random ID.

    Activity activity = new Activity(
        activityID: activityID,
        typeOfAction: typeOfAction,
        doneBy: Get.find<UserController>().user.userName,
        date: Timestamp.now());

    // Convert the activity object to JSON

    var activityJSON = activity.toJson();

    try {
      return await _firestore
          .collection('projects')
          .document(projectID)
          .collection('activityLog')
          .document(activityID)
          .setData(activityJSON);
    } on Exception catch (e) {
      print(e);
    }
  }

  Stream<List<Activity>> streamActivityLogOfProject(String projectID) {
    return _firestore
        .collection('projects')
        .document(projectID)
        .collection('activityLog')
        .snapshots()
        .map((QuerySnapshot query) {
      List<Activity> retVal = List();
      query.documents.forEach((element) {
        retVal.add(Activity.fromJson(element.data));
      });
      return retVal;
    });
  }

  Future<void> deleteProject(String projectID) async {
    try {
      _firestore.collection('projects').document(projectID).delete();
    } on Exception catch (e) {
      print(e);
    }
  }

  Future<void> changeMainTaskStatus(
      String projectID, String taskID, String taskStatus) async {
    // Record this action in the activity log of the project
    insertIntoActivityLog(projectID, "Updated task statues to '$taskStatus'");

    updateTaskNotificationByAssignedMember(projectID, taskID);

    try {
      _firestore
          .collection('projects')
          .document(projectID)
          .collection('tasks')
          .document(taskID)
          .updateData(({"taskStatus": taskStatus}));
    } on Exception catch (e) {
      print(e);
    }
  }

  Future<void> changeSubtaskStatus(
      String projectID,
      String taskID,
      String subtaskID,
      String subtaskName,
      String subtaskDescription,
      String startDate,
      String dueDate,
      String subtaskPriority,
      String oldSubtaskStatus,
      String newSubTaskStatus) async {
    // Record this action in the activity log of the project
    insertIntoActivityLog(
        projectID, "Updated a subtask status to '$newSubTaskStatus'");

    await deleteSubtask(
            projectID,
            taskID,
            subtaskID,
            subtaskName,
            subtaskDescription,
            startDate,
            dueDate,
            subtaskPriority,
            oldSubtaskStatus)
        .then((value) async {})
        .then((value) async {
      await createNewSubtask(projectID, taskID, subtaskName, subtaskDescription,
          startDate, dueDate, subtaskPriority, newSubTaskStatus);
    });
  }
}
