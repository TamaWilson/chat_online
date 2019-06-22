import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

void main() {
  runApp(MyApp());
}

final ThemeData kIOSTheme = ThemeData(
    primarySwatch: Colors.orange,
    primaryColor: Colors.grey[100],
    primaryColorBrightness: Brightness.light);

final ThemeData kDefaultTheme = ThemeData(
  primarySwatch: Colors.purple,
  accentColor: Colors.orangeAccent[400],
);

final googleSignIn = GoogleSignIn();
final auth = FirebaseAuth.instance;

_ensureLoggerIn() async {
  GoogleSignInAccount user = googleSignIn.currentUser;
  if (user == null) {
    user = await googleSignIn.signInSilently();
  }
  if (user == null) {
    user = await googleSignIn.signIn();
  }
  if (await auth.currentUser() == null) {
    GoogleSignInAuthentication credentials =
        await googleSignIn.currentUser.authentication;
    await auth.signInWithCredential(GoogleAuthProvider.getCredential(
        idToken: credentials.idToken, accessToken: credentials.accessToken));
  }
}

_handleSubmited(String text) async {
  await _ensureLoggerIn();
  _sendMessage(text: text);
}

void _sendMessage({String text, String imgUrl}) {
  Firestore.instance.collection("messages").add({
    "text": text,
    "image": imgUrl,
    "senderName": googleSignIn.currentUser.displayName,
    "senderPhotoUrl": googleSignIn.currentUser.photoUrl,
    "senderId": googleSignIn.currentUser.id
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Chat Online",
      theme: Theme.of(context).platform == TargetPlatform.iOS
          ? kIOSTheme
          : kDefaultTheme,
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {



  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Chat App"),
          centerTitle: true,
          elevation:
              Theme.of(context).platform == TargetPlatform.iOS ? 0.0 : 4.0,
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: StreamBuilder(
                stream: Firestore.instance.collection("messages").snapshots(),
                builder: (context, snapshot) {
                  switch (snapshot.connectionState) {
                    case (ConnectionState.none):
                    case (ConnectionState.waiting):
                      return Center(
                        child: CircularProgressIndicator(),
                      );
                    default:
                      return ListView.builder(
                          reverse: true,
                          itemCount: snapshot.data.documents.length,
                          itemBuilder: (context, index) {
                            List reversed = snapshot.data.documents.reversed.toList();
                            return ChatMessage(reversed[index].data);
                          });
                  }
                },
              ),
            ),
            Divider(
              height: 1.0,
            ),
            Container(
              decoration: BoxDecoration(color: Theme.of(context).cardColor),
              child: TextComposer(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _ensureLoggerIn();
  }
}

class TextComposer extends StatefulWidget {
  @override
  _TextComposerState createState() => _TextComposerState();
}

class _TextComposerState extends State<TextComposer> {
  bool _isComposing = false;

  final _textController = TextEditingController();

  void _reset() {
    _textController.clear();
    setState(() {
      _isComposing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).accentColor),
      child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8.0),
          decoration: Theme.of(context).platform == TargetPlatform.iOS
              ? BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey[200])))
              : null,
          child: Row(
            children: <Widget>[
              Container(
                child: IconButton(
                    icon: Icon(Icons.photo_camera),
                    onPressed: () async {
                      await _ensureLoggerIn();
                      File imgFile = await ImagePicker.pickImage(source: ImageSource.camera);
                      if(imgFile == null) return;
                      StorageUploadTask task = FirebaseStorage.instance.ref().child(googleSignIn.currentUser.id.toString() +
                          DateTime.now().millisecondsSinceEpoch.toString()).putFile(imgFile);
                      StorageTaskSnapshot taskSnapshot = await task.onComplete;
                      String url = await taskSnapshot.ref.getDownloadURL();
                      _sendMessage(imgUrl: url);
                    }),
              ),
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(hintText: "Digite sua mensagem"),
                  onChanged: (text) {
                    setState(() {
                      _isComposing = text.length > 0;
                    });
                  },
                  onSubmitted: (text) {
                    _handleSubmited(text);
                    _reset();
                  },
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Theme.of(context).platform == TargetPlatform.iOS
                    ? CupertinoButton(
                        child: Text("ENVIAR"),
                        onPressed: _isComposing
                            ? () {
                                _handleSubmited(_textController.text);
                                _reset();
                              }
                            : null,
                      )
                    : IconButton(
                        icon: Icon(Icons.send),
                        onPressed: _isComposing
                            ? () {
                                _handleSubmited(_textController.text);
                                _reset();
                              }
                            : null,
                      ),
              )
            ],
          )),
    );
  }
}

class ChatMessage extends StatelessWidget {

  final Map<String, dynamic> data;

  ChatMessage(this.data);
  bool _isMe() {
    if (googleSignIn.currentUser == null) {
      return false;
    }
    return data["senderId"] == googleSignIn.currentUser.id;
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
      child: Container(
        padding: _isMe() ? EdgeInsets.only(left: 100.0) : EdgeInsets.only(right: 100.0),
        child: Card(
          color: _isMe() ? Colors.lightGreen[200] : Colors.white,
          child: Padding(padding: EdgeInsets.all(10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: _cardChildren(context) ,
          ),),
        ),
      )
    );
  }

  List<Widget> _cardChildren(context){

    List<Widget> widgetsList = [
      Container(
          margin: _isMe() ? const EdgeInsets.only(left: 7.0) : const EdgeInsets.only(right: 7.0),
          child: CircleAvatar(
            backgroundImage:
            NetworkImage(data["senderPhotoUrl"]),
          )),
      Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(data["senderName"], style: TextStyle(fontSize: 13.0,
              fontWeight: FontWeight.bold)),
              Container(
                margin: const EdgeInsets.only(top: 5.0),
                child: data["image"] != null ?
                Image.network(data["image"], width:  250.0,) :
                Text(data["text"]),
              )
            ],
          ))
    ];

    if(_isMe()){
      return widgetsList.reversed.toList();
    } else {
      return widgetsList;
    }
  }

}
