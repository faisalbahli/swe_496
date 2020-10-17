import 'package:flutter/material.dart';
import 'package:multilevel_drawer/multilevel_drawer.dart';
import 'package:get/get.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:swe496/Database/UserProfileCollection.dart';
import 'package:swe496/Views/Account_Settings.dart';
import 'package:swe496/controllers/authController.dart';
import 'package:swe496/controllers/userController.dart';
import 'package:swe496/Views/SignIn.dart';

class FriendsView extends StatefulWidget {
  @override
  _FriendsViewState createState() => _FriendsViewState();
}

class _FriendsViewState extends State<FriendsView> {

  int barIndex = 2; // Currently we are at 2 for bottom navigation tabs
  AuthController authController = Get.find<AuthController>();
  UserController userController = Get.find<UserController>();

  final formKey = GlobalKey<FormState>();
  final TextEditingController _friendUsernameController =TextEditingController();


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomPadding: false,
        // still not working in landscape mode
        appBar: AppBar(
          title: const Text('Group Projects'),
          centerTitle: true,
          backgroundColor: Colors.red,
          actions: <Widget>[],
        ),
        drawer: MultiLevelDrawer(
          backgroundColor: Colors.white,
          rippleColor: Colors.grey.shade100,
          subMenuBackgroundColor: Colors.grey.shade100,
          divisionColor: Colors.black12,
          header: Container(
            // Header for Drawer
            height: MediaQuery.of(context).size.height * 0.25,
            child: Center(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                CircleAvatar(
                  radius: 40,
                ),
                SizedBox(
                  height: 10,
                ),
                userController.user.userName == null
                      ? Text('NULL ??')
                      : Text('${userController.user.userName}'),
              ],
            )),
          ),
          children: [
            // Child Elements for Each Drawer Item
            MLMenuItem(
                leading: Icon(
                  Icons.person,
                  color: Colors.red,
                ),
                content: Text(
                  "My Profile",
                ),
                onClick: () {
                  Get.to(AccountSettings());
                }),
                
            MLMenuItem(
              leading: Icon(Icons.settings, color: Colors.red),
              content: Text("Settings"),
              onClick: () {},
            ),
            MLMenuItem(
                leading: Icon(Icons.power_settings_new, color: Colors.red),
                content: Text(
                  "Log out",
                ),
                onClick: () async {
                  try {
                    //AuthService auth = Provider.of(context).auth;
                    //await auth.signOut();
                    Get.off(SignIn());
                    print("Signed Out");
                  } catch (e) {
                    print(e.toString());
                  }
                }),
          ],
        ),
        body: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: Column(
            children: <Widget>[
              _searchBar(),

            ],
          ),
        ),
        bottomNavigationBar: bottomCustomNavigationBar(),
        floatingActionButton: floatingButtons());
  }

  // Search Bar
  _searchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        decoration: InputDecoration(hintText: 'Search'),
        onChanged: (textVal) {
          textVal = textVal.toLowerCase();
          setState(() {});
        },
      ),
    );
  }


  void alertAddFriend() {
     Alert(
        context: context,
        title: "Edit",
        content: Form(
                  key: formKey,
                  child: Column(
            children: <Widget>[
             TextFormField(
                    validator: (value) => 
                    value.isEmpty ? "username can't be empty" : null,
                    controller: _friendUsernameController,
                    onSaved: (val) =>
                        _friendUsernameController.text = val,
                    decoration: InputDecoration(
                      icon: Icon(Icons.edit),
                      focusedBorder: UnderlineInputBorder(),
                      hintText: 'enter Friend username',
                      
                    ),
                  ),
             
            ],
          ),
        ),
        buttons: [
          DialogButton(
            onPressed: () async{
              formKey.currentState.save();
              if (formKey.currentState.validate()) {
                try{
                  await UserProfileCollection().addFriend(_friendUsernameController.text,userController.user);
                   _friendUsernameController.clear();
                   Navigator.pop(context);
                }catch(e){
                  print("error");
                }
              }
              

            },
            child: Text(
              "submit",
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          )
        ]).show();
  }

  Widget bottomCustomNavigationBar() {
    return BottomNavigationBar(
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.people),
          title: Text('Groups'),
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.assignment_turned_in),
          title: Text('Tasks'),
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.contacts),
          title: Text('Friends'),
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.message),
          title: Text('Messages'),
        ),
        /* BottomNavigationBarItem(
          icon: Icon(Icons.person_pin),
          title: Text('Account'),
        ),*/
      ],
      currentIndex: barIndex,
      selectedItemColor: Colors.red,
      unselectedItemColor: Colors.grey,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedFontSize: 15,
      onTap: (index) {
        setState(() {
          barIndex = index;
        });
        print(index);
      },
    );
  }

  // Buttons for creating or joining project
  Widget floatingButtons() {
    return SpeedDial(
      // both default to 16
      marginRight: 18,
      marginBottom: 20,
      animatedIcon: AnimatedIcons.menu_close,
      animatedIconTheme: IconThemeData(size: 25.0),
      // this is ignored if animatedIcon is non null
      // child: Icon(Icons.add),
      // If true user is forced to close dial manually
      // by tapping main button and overlay is not rendered.
      closeManually: false,
      curve: Curves.bounceIn,
      overlayColor: Colors.black,
      overlayOpacity: 0.3,
      onOpen: () => print('OPENING MENU'),
      onClose: () => print('MENU CLOSED'),
      tooltip: 'Menu',
      heroTag: '',
      backgroundColor: Colors.white,
      foregroundColor: Colors.red,
      elevation: 8.0,
      shape: CircleBorder(),
      children: [
        SpeedDialChild(
          child: Icon(
            Icons.group_add,
            size: 25,
          ),
          backgroundColor: Colors.red,
          label: 'add friend',
          labelStyle: TextStyle(fontSize: 16.0),
          onTap: () {
            print('SECOND CHILD');
            alertAddFriend();
            

          } ,
        ),
      ],
    );
  }
}
