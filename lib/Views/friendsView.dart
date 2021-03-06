import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:swe496/Views/MessagesView.dart';
import 'package:swe496/Views/private_folder_views/private_folder_view.dart';
import 'package:swe496/Views/the_drawer.dart';
import 'package:swe496/utils/root.dart';
import '../Database/UserProfileCollection.dart';
import '../controllers/UserControllers/authController.dart';
import '../controllers/UserControllers/userController.dart';

class FriendsView extends StatefulWidget {
  @override
  _FriendsViewState createState() => _FriendsViewState();
}

class _FriendsViewState extends State<FriendsView> {
  int barIndex = 2; // Currently we are at 2 for bottom navigation tabs
  AuthController authController = Get.find<AuthController>();
  UserController userController = Get.find<UserController>();

  final formKey = GlobalKey<FormState>();
  final TextEditingController _friendUsernameController =
      TextEditingController();
   List<DocumentSnapshot> filteredFriendsListBySearch;
   String keyword="";   

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomPadding: false,
      // still not working in landscape mode
      appBar: AppBar(
        title: const Text('Friends'),
        centerTitle: true,
        actions: <Widget>[],
      ),
      drawer: TheDrawer(authController: authController),
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: SingleChildScrollView(
                  child: Column(
            children: <Widget>[
              _searchBar(),
              getListOfFriends(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: bottomCustomNavigationBar(),
      floatingActionButton: FloatingActionButton(
          child: Icon(Icons.person_add), onPressed: () => alertAddFriend()),
    );
  }

  // Search Bar
  _searchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        decoration: InputDecoration(hintText: 'Search'),
        onChanged: (textVal) {
          
          
          setState(() {
            keyword =textVal;
          });
        },
      ),
    );
  }

  void alertAddFriend() {
    Alert(
        context: context,
        title: "Add New Friend",
        content: Form(
          key: formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                validator: (value) =>
                    value.isEmpty ? "username can't be empty" : null,
                controller: _friendUsernameController,
                onSaved: (val) => _friendUsernameController.text = val,
                decoration: InputDecoration(
                  icon: Icon(Icons.edit),
                  focusedBorder: UnderlineInputBorder(),
                  hintText: 'Enter a username',
                ),
              ),
            ],
          ),
        ),
        buttons: [
          DialogButton(
            onPressed: () async {
              formKey.currentState.save();
              if (formKey.currentState.validate()) {
                try {
                  await UserProfileCollection().addFriend(
                      _friendUsernameController.text, userController.user);
                  _friendUsernameController.clear();
                  Navigator.pop(context);
                } catch (e) {
                  Get.snackbar('Error', 'error');
                }
              }
            },
            child: Text(
              "Submit",
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          )
        ]).show();
  }

  Widget getListOfFriends() {
    return StreamBuilder<QuerySnapshot>(
      stream: Firestore.instance
          .collection('userProfile')
          .where('friendsIDs', arrayContains: userController.user.userID)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return Text(snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.active) {
          if (snapshot.hasData && snapshot.data != null) {
            if (snapshot.data.documents.length == 0)
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(child: Text("You don't have any friends")),
              );
               filteredFriendsListBySearch = snapshot.data.documents.toList()
                  .where((user) => user.data["userName"]
                      .toLowerCase()
                      .contains(keyword.toLowerCase()))
                  .toList();
           
            return ListView.builder(
                itemCount: filteredFriendsListBySearch.length,
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: Icon(Icons.account_circle),
                    title: Text(filteredFriendsListBySearch[index]['userName']),
                    subtitle: Text('Click to chat'),
                    onTap: () {
                      String firstname = userController.user.userName.compareTo(filteredFriendsListBySearch[index]['userName'])==-1? userController.user.userName:filteredFriendsListBySearch[index]['userName'];
                      String secondname = userController.user.userName.compareTo(filteredFriendsListBySearch[index]['userName'])==1? userController.user.userName:filteredFriendsListBySearch[index]['userName'];
                      String chatname = firstname + '#' + secondname;
                      String chatID = firstname + secondname ;
                      // if chat id not in the userChatsIDs create new a chat and it both friends
                      if(userController.user.userChatsIDs.contains(chatID)){
                          Get.to(MessagesView.direct(chatID , true , chatname ), transition: Transition.noTransition);
                      } else {
                        List<String> membersIDs = new List<String>();
                        membersIDs.add(userController.user.userID);
                        membersIDs.add(filteredFriendsListBySearch[index]['userID']);
                        try {
                       for (int i = 0; i < membersIDs.length; i++) {
                         Firestore.instance.collection('userProfile')
                          .document(membersIDs[i])
                          .updateData(({
                          'userChatsIDs': FieldValue.arrayUnion([chatID]),
                                       }));
                                                                   }
                       Map<String, dynamic> chatInfo = new Map<String, dynamic>();
                       chatInfo['GroupName'] = firstname + '#' + secondname;
                       chatInfo['LastMsg'] = "";
                       chatInfo['membersIDs'] = membersIDs;
                       chatInfo['type'] = 'private';
                       Firestore.instance.collection('Chats').document(chatID).setData(chatInfo);
                          Get.to(MessagesView.direct(chatID , true , chatname ), transition: Transition.noTransition);
                            } catch (e) {
                                   print(e);
                                        }
                        
                      }
                    },
                  );
                });
          }
        }
        return Container(
          child: Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Loading',
              strokeWidth: 4,
            ),
          ),
        );
      },
    );
  }

  Widget bottomCustomNavigationBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Groups',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.assignment_turned_in),
          label: 'Tasks',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.contacts),
          label: 'Friends',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.message),
          label: 'Messages',
        ),
      ],
      currentIndex: barIndex,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      onTap: (index) {
        setState(() {
          barIndex = index;

          barIndex = index;

          if (barIndex == 0)
            Get.to(Root());
          else if (barIndex == 1)
            Get.off(PrivateFolderView());
          else if (barIndex == 2) // Do nothing, stay in the same page
           return;
          else if (barIndex == 3)
            Get.off(MessagesView());
        });
        print(index);
      },
    );
  }

// Buttons for creating or joining project
}
