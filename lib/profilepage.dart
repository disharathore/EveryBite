import 'package:everybite/TandC.dart';
import 'package:everybite/bottomnav.dart';
import 'package:everybite/chatscreen.dart';
import 'package:everybite/editpage.dart';
import 'package:everybite/homepage.dart';
import 'package:everybite/loginpage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:everybite/services/mongo_user_service.dart';
import 'package:everybite/services/session_service.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? userId;
  String profilePicPath = "";
  String userName = "Bushra";

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  // Fetch user data for the current session user.
  void _getUserData() async {
    userId = SessionService.currentUserId;
    if (userId != null && userId!.isNotEmpty) {
      final userDoc = await MongoUserService.instance.getUserById(userId!);
      if (userDoc != null) {
        setState(() {
          userName = (userDoc['full_name'] ?? 'User').toString();
        });
      }
    } else {
      // If no user is logged in, navigate to login page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    }
  }

  // Pick and preview profile picture locally.
  Future<void> _updateProfilePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        profilePicPath = image.path;
      });
    }
  }

  void navigateToChatScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ChatScreen()), // ChatScreen is your chat screen
    );
  }

  void navigateToHomePage(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const Homepage()),
    );
  }

  void navigateToProfilePage(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ProfilePage()),
    );
  }

  // Sign out the user
  void _signOut() async {
    SessionService.clear();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
      (Route<dynamic> route) => false, // Removes all previous routes
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: Center(
          child: Column(
            children: [
              SizedBox(height: 40),
              // Profile Image (Tap to change)
              GestureDetector(
                onTap: _updateProfilePicture,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: profilePicPath.isNotEmpty
                      ? FileImage(File(profilePicPath))
                      : AssetImage("assets/image/4.png") as ImageProvider,
                ),
              ),
              SizedBox(height: 10),
              // Display User Name
              Text(
                userName,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              // Buttons
              _buildProfileButton("Edit Personal Details", Icons.edit, () {
                // Navigating to EditProfile page when the button is pressed
                if (userId == null || userId!.isEmpty) {
                  return;
                }
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          EditProfile(userId: userId!), // Pass userId
                    ));
              }),
              _buildProfileButton("Terms and Policy", Icons.description, () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          TermsAndConditionsPage(), // Pass userId
                    ));
              }),
              _buildProfileButton("Sign Out", Icons.logout, _signOut),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 2, // Profile Tab Index
        navigateToHomePage: () => navigateToHomePage(context),
        navigateToProfilePage: () => navigateToProfilePage(context),
        navigateToScanPage: () => navigateToChatScreen(context),
      ),
    );
  }

  // Custom Button Widget (Full Width)
  Widget _buildProfileButton(String text, IconData icon, Function onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 70, // Full width
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[400],
            padding: EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => onTap(),
          icon: Icon(icon, color: Colors.white),
          label: Text(text, style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
