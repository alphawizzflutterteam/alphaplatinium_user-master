import 'dart:async';
import 'dart:convert';
import 'package:alphasilver_multivendor/Helper/String.dart';
import 'package:alphasilver_multivendor/Helper/cropped_container.dart';
import 'package:alphasilver_multivendor/Provider/SettingProvider.dart';
import 'package:alphasilver_multivendor/Provider/UserProvider.dart';
import 'package:alphasilver_multivendor/Screen/SendOtp.dart';
import 'package:alphasilver_multivendor/Screen/SignUp.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart';
import 'package:provider/provider.dart';
import '../Helper/AppBtn.dart';
import '../Helper/Color.dart';
import '../Helper/Constant.dart';
import '../Helper/Session.dart';

class Login extends StatefulWidget {
  @override
  _LoginPageState createState() => new _LoginPageState();
}

class _LoginPageState extends State<Login> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  final mobileController = TextEditingController();
  final passwordController = TextEditingController();
  String? countryName;
  FocusNode? passFocus, monoFocus = FocusNode();

  final GlobalKey<FormState> _formkey = GlobalKey<FormState>();
  bool visible = false;
  String? password,
      mobile,
      username,
      email,
      id,
      mobileno,
      city,
      area,
      pincode,
      address,
      latitude,
      longitude,
      image;
  bool _isNetworkAvail = true;
  String? fcmToken;
  Animation? buttonSqueezeanimation;
  AnimationController? buttonController;

  getToken(){
    FirebaseMessaging.instance.getToken().then((value) {
      fcmToken = value!;
    });
    print("fcm is ${fcmToken}");
  }

  @override
  void initState() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: [SystemUiOverlay.top]);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    super.initState();
    getToken();
    buttonController = new AnimationController(
        duration: new Duration(milliseconds: 2000), vsync: this);
    buttonSqueezeanimation = new Tween(
      begin: deviceWidth! * 0.7,
      end: 50.0,
    ).animate(new CurvedAnimation(
      parent: buttonController!,
      curve: new Interval(
        0.0,
        0.150,
      ),
    ));
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    buttonController!.dispose();
    super.dispose();
  }

  Future<Null> _playAnimation() async {
    try {
      await buttonController!.forward();
    } on TickerCanceled {}
  }

  void validateAndSubmit() async {
    if (validateAndSave()) {
      _playAnimation();
      checkNetwork();
    }
  }

  Future<void> checkNetwork() async {
    _isNetworkAvail = await isNetworkAvailable();
    if (_isNetworkAvail) {
      getLoginUser();
    } else {
      Future.delayed(Duration(seconds: 2)).then((_) async {
        await buttonController!.reverse();
        if (mounted)
          setState(() {
            _isNetworkAvail = false;
          });
      });
    }
  }

  bool validateAndSave() {
    final form = _formkey.currentState!;
    form.save();
    if (form.validate()) {
      return true;
    }
    return false;
  }

  setSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
      content: new Text(
        msg,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.fontColor),
      ),
      backgroundColor: Theme.of(context).colorScheme.lightWhite,
      elevation: 1.0,
    ));
  }

  Widget noInternet(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.only(top: kToolbarHeight),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          noIntImage(),
          noIntText(context),
          noIntDec(context),
          AppBtn(
            title: getTranslated(context, 'TRY_AGAIN_INT_LBL'),
            btnAnim: buttonSqueezeanimation,
            btnCntrl: buttonController,
            onBtnSelected: () async {
              _playAnimation();

              Future.delayed(Duration(seconds: 2)).then((_) async {
                _isNetworkAvail = await isNetworkAvailable();
                if (_isNetworkAvail) {
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (BuildContext context) => super.widget));
                } else {
                  await buttonController!.reverse();
                  if (mounted) setState(() {});
                }
              });
            },
          )
        ]),
      ),
    );
  }

  Future<void> getLoginUser() async {
    print("this is fcm Token $fcmToken");
    var data = {MOBILE: mobile, PASSWORD: password, "fcm_id": fcmToken};
    print(data);
    Response response =
    await post(getUserLoginApi, body: data, headers: headers)
        .timeout(Duration(seconds: timeOut));
    var getdata = json.decode(response.body);
    bool error = getdata["error"];
    String? msg = getdata["message"];
    await buttonController!.reverse();
    if (!error) {
      setSnackbar(msg!);
      var i = getdata["data"][0];
      id = i[ID];
      username = i[USERNAME];
      email = i[EMAIL];
      mobile = i[MOBILE];
      city = i[CITY];
      area = i[AREA];
      address = i[ADDRESS];
      pincode = i[PINCODE];
      latitude = i[LATITUDE];
      longitude = i[LONGITUDE];
      image = i[IMAGE];

      CUR_USERID = id;
      // CUR_USERNAME = username;

      UserProvider userProvider =
      Provider.of<UserProvider>(this.context, listen: false);
      userProvider.setName(username ?? "");
      userProvider.setEmail(email ?? "");
      userProvider.setProfilePic(image ?? "");

      SettingProvider settingProvider =
      Provider.of<SettingProvider>(context, listen: false);

      settingProvider.saveUserDetail(id!, username, email, mobile, city, area,
          address, pincode, latitude, longitude, image, context);

      Navigator.pushNamedAndRemoveUntil(context, "/home", (r) => false);
    } else {
      setSnackbar(msg!);
    }
  }

  _subLogo() {
    return Expanded(
      flex: 4,
      child: Center(
        child: Image.asset(
          'assets/images/homelogo.png',
        ),
      ),
    );
  }

  signInTxt() {
    return Padding(
        padding: EdgeInsetsDirectional.only(
          top: 30.0,
        ),
        child: Align(
          alignment: Alignment.center,
          child: new Text(
            getTranslated(context, 'SIGNIN_LBL')!,
            style: Theme.of(context).textTheme.subtitle1!.copyWith(
                color: Theme.of(context).colorScheme.fontColor,
                fontWeight: FontWeight.bold),
          ),
        ));
  }

  // setMobileNo() {
  //   return Container(
  //     width: MediaQuery.of(context).size.width * 0.85,
  //     padding: EdgeInsets.only(
  //       top: 30.0,
  //     ),
  //     child: TextFormField(
  //       maxLength: 10,
  //       onFieldSubmitted: (v) {
  //         FocusScope.of(context).requestFocus(passFocus);
  //       },
  //       keyboardType: TextInputType.number,
  //       controller: mobileController,
  //       style: TextStyle(
  //         color: Theme.of(context).colorScheme.fontColor,
  //         fontWeight: FontWeight.normal,
  //       ),
  //       focusNode: monoFocus,
  //       textInputAction: TextInputAction.next,
  //       inputFormatters: [FilteringTextInputFormatter.digitsOnly],
  //       validator: (val) => validateMob(
  //           val!,
  //           getTranslated(context, 'MOB_REQUIRED'),
  //           getTranslated(context, 'VALID_MOB')),
  //       onSaved: (String? value) {
  //         mobile = value;
  //       },
  //       decoration: InputDecoration(
  //         counterText: '',
  //         prefixIcon: Icon(
  //           Icons.phone_android,
  //           color: Theme.of(context).colorScheme.fontColor,
  //           size: 20,
  //         ),
  //         hintText: getTranslated(context, 'MOBILEHINT_LBL'),
  //         hintStyle: Theme.of(this.context).textTheme.subtitle2!.copyWith(
  //             color: Theme.of(context).colorScheme.fontColor,
  //             fontWeight: FontWeight.normal),
  //         filled: true,
  //         fillColor: Theme.of(context).colorScheme.white,
  //         contentPadding: EdgeInsets.symmetric(
  //           horizontal: 10,
  //           vertical: 5,
  //         ),
  //         focusedBorder: UnderlineInputBorder(
  //           borderSide: BorderSide(color: colors.primary),
  //           borderRadius: BorderRadius.circular(7.0),
  //         ),
  //         prefixIconConstraints: BoxConstraints(
  //           minWidth: 40,
  //           maxHeight: 20,
  //         ),
  //
  //         enabledBorder: UnderlineInputBorder(
  //           borderSide:
  //           BorderSide(color: Theme.of(context).colorScheme.lightBlack2),
  //           borderRadius: BorderRadius.circular(7.0),
  //         ),
  //       ),
  //     ),
  //   );
  //
  //   return Container(
  //     width: deviceWidth! * 0.7,
  //     padding: EdgeInsetsDirectional.only(
  //       top: 30.0,
  //     ),
  //     child: TextFormField(
  //       onFieldSubmitted: (v) {
  //         FocusScope.of(context).requestFocus(passFocus);
  //       },
  //       keyboardType: TextInputType.number,
  //       controller: mobileController,
  //       style: TextStyle(
  //           color: Theme.of(context).colorScheme.fontColor,
  //           fontWeight: FontWeight.normal),
  //       focusNode: monoFocus,
  //       textInputAction: TextInputAction.next,
  //       inputFormatters: [FilteringTextInputFormatter.digitsOnly],
  //       validator: (val) => validateMob(
  //           val!,
  //           getTranslated(context, 'MOB_REQUIRED'),
  //           getTranslated(context, 'VALID_MOB')),
  //       onSaved: (String? value) {
  //         mobile = value;
  //       },
  //       decoration: InputDecoration(
  //         prefixIcon: Icon(
  //           Icons.call_outlined,
  //           color: Theme.of(context).colorScheme.fontColor,
  //           size: 17,
  //         ),
  //         hintText: getTranslated(context, 'MOBILEHINT_LBL'),
  //         hintStyle: Theme.of(this.context).textTheme.subtitle2!.copyWith(
  //             color: Theme.of(context).colorScheme.fontColor,
  //             fontWeight: FontWeight.normal),
  //         filled: true,
  //         fillColor: Theme.of(context).colorScheme.lightWhite,
  //         contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  //         prefixIconConstraints: BoxConstraints(minWidth: 40, maxHeight: 20),
  //         focusedBorder: OutlineInputBorder(
  //           borderSide:
  //           BorderSide(color: Theme.of(context).colorScheme.fontColor),
  //           borderRadius: BorderRadius.circular(7.0),
  //         ),
  //         enabledBorder: UnderlineInputBorder(
  //           borderSide:
  //           BorderSide(color: Theme.of(context).colorScheme.lightWhite),
  //           borderRadius: BorderRadius.circular(7.0),
  //         ),
  //       ),
  //     ),
  //   );
  // }
  setMobileNo() {
    return Container(
      width: MediaQuery.of(context).size.width,
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.only(
        top: 30.0,
      ),
      child: TextFormField(
        maxLength: 10,
        onFieldSubmitted: (v) {
          FocusScope.of(context).requestFocus(passFocus);
        },
        keyboardType: TextInputType.number,
        controller: mobileController,
        style: TextStyle(
          color: Theme.of(context).colorScheme.fontColor,
          fontWeight: FontWeight.normal,
        ),
        focusNode: monoFocus,
        textInputAction: TextInputAction.next,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (val) => validateMob(
            val!,
            getTranslated(context, 'MOB_REQUIRED'),
            getTranslated(context, 'VALID_MOB')),
        onSaved: (String? value) {
          mobile = value;
        },
        decoration: InputDecoration(
            border:InputBorder.none,
            counterText: '',
            // prefixIcon: ImageIcon(
            //   AssetImage('assets/images/Call.png'),
            //   color: Theme.of(context).colorScheme.lightBlack,
            // ),
          prefixIcon:Icon(
              Icons.phone_android,
              color: Theme.of(context).colorScheme.fontColor,
              size: 20,
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(8),
            ),
            disabledBorder: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(8)),
            hintText: getTranslated(context, 'MOBILEHINT_LBL'),
            fillColor: Colors.grey.shade100,
            filled: true),
      ),
    );
  }

  // setPass() {
  //   return Container(
  //     width: MediaQuery.of(context).size.width * 0.85,
  //     padding: EdgeInsets.only(
  //       top: 15.0,
  //     ),
  //     child: TextFormField(
  //       onFieldSubmitted: (v) {
  //         FocusScope.of(context).requestFocus(passFocus);
  //       },
  //       keyboardType: TextInputType.text,
  //       obscureText: true,
  //       controller: passwordController,
  //       style: TextStyle(
  //           color: Theme.of(context).colorScheme.fontColor,
  //           fontWeight: FontWeight.normal),
  //       focusNode: passFocus,
  //       textInputAction: TextInputAction.next,
  //       validator: (val) => validatePass(
  //           val!,
  //           getTranslated(context, 'PWD_REQUIRED'),
  //           getTranslated(context, 'PWD_LENGTH')),
  //       onSaved: (String? value) {
  //         password = value;
  //       },
  //       decoration: InputDecoration(
  //         prefixIcon: SvgPicture.asset(
  //           "assets/images/password.svg",
  //           color: Theme.of(context).colorScheme.fontColor,
  //         ),
  //
  //         suffixIcon: InkWell(
  //           onTap: () {
  //             // SettingProvider settingsProvider =
  //             // Provider.of<SettingProvider>(this.context, listen: false);
  //             //
  //             // settingsProvider.setPrefrence(ID, id!);
  //             // settingsProvider.setPrefrence(MOBILE, mobile!);
  //
  //             Navigator.push(
  //                 context,
  //                 MaterialPageRoute(
  //                     builder: (context) => SendOtp(
  //                       checkForgot : "true",
  //                       title: getTranslated(context, 'FORGOT_PASS_TITLE'),
  //                     )));
  //           },
  //           child: Text(
  //             getTranslated(context, "FORGOT_LBL")!,
  //             style: TextStyle(
  //               color: colors.primary,
  //               fontSize: 12,
  //               fontWeight: FontWeight.bold,
  //             ),
  //           ),
  //         ),
  //         hintText: getTranslated(context, "PASSHINT_LBL")!,
  //         hintStyle: Theme.of(this.context).textTheme.subtitle2!.copyWith(
  //             color: Theme.of(context).colorScheme.fontColor,
  //             fontWeight: FontWeight.normal),
  //         //filled: true,
  //         fillColor: Theme.of(context).colorScheme.white,
  //         contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  //         suffixIconConstraints: BoxConstraints(minWidth: 40, maxHeight: 20),
  //         prefixIconConstraints: BoxConstraints(minWidth: 40, maxHeight: 20),
  //         // focusedBorder: OutlineInputBorder(
  //         //     //   borderSide: BorderSide(color: fontColor),
  //         //     // borderRadius: BorderRadius.circular(7.0),
  //         //     ),
  //         focusedBorder: UnderlineInputBorder(
  //           borderSide: BorderSide(color: colors.primary),
  //           borderRadius: BorderRadius.circular(7.0),
  //         ),
  //         enabledBorder: UnderlineInputBorder(
  //           borderSide:
  //           BorderSide(color: Theme.of(context).colorScheme.lightBlack2),
  //           borderRadius: BorderRadius.circular(7.0),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  setPass() {
    return Container(
      width: MediaQuery.of(context).size.width,
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.only(
        top: 15.0,
      ),
      child: TextFormField(
        onFieldSubmitted: (v) {
          FocusScope.of(context).requestFocus(passFocus);
        },
        keyboardType: TextInputType.text,
        obscureText: true,
        controller: passwordController,
        style: TextStyle(
            color: Theme.of(context).colorScheme.fontColor,
            fontWeight: FontWeight.normal),
        focusNode: passFocus,
        textInputAction: TextInputAction.next,
        validator: (val) => validatePass(
            val!,
            getTranslated(context, 'PWD_REQUIRED'),
            getTranslated(context, 'PWD_LENGTH')),
        onSaved: (String? value) {
          password = value;
        },
        decoration: InputDecoration(
            border:InputBorder.none,
            // prefixIcon: ImageIcon(
            //   AssetImage('assets/images/Unlock.png'),
            //   color: Theme.of(context).colorScheme.lightBlack,
            // ),
            prefixIcon: Icon(
              Icons.lock,
              color: Theme.of(context).colorScheme.fontColor,
              size: 20,
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(8),
            ),
            disabledBorder: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(8)),
            hintText: getTranslated(context, "PASSHINT_LBL")!,
            fillColor: Colors.grey.shade100,
            filled: true),
      ),
    );
  }

  forgetPass() {
    return Padding(
        padding: EdgeInsetsDirectional.only(start: 25.0, end: 25.0, top: 10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            InkWell(
              onTap: () {
                SettingProvider settingsProvider =
                Provider.of<SettingProvider>(this.context, listen: false);

                settingsProvider.setPrefrence(ID, id ?? '');
                settingsProvider.setPrefrence(
                    MOBILE, mobileController.text ?? '');

                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => SendOtp(
                          checkForgot: 'true',
                          title:
                          getTranslated(context, 'FORGOT_PASS_TITLE'),
                        )));
              },
              child: Text(getTranslated(context, 'FORGOT_PASSWORD_LBL')!,
                  style: Theme.of(context).textTheme.subtitle2!.copyWith(
                      color: Theme.of(context).colorScheme.fontColor,
                      fontWeight: FontWeight.normal)),
            ),
          ],
        ));
  }

  // forgetPass() {
  //   return Padding(
  //       padding: EdgeInsetsDirectional.only(start: 25.0, end: 25.0, top: 10.0),
  //       child: Row(
  //         mainAxisAlignment: MainAxisAlignment.end,
  //         children: <Widget>[
  //           InkWell(
  //             onTap: () {
  //               SettingProvider settingsProvider =
  //               Provider.of<SettingProvider>(this.context, listen: false);
  //
  //               settingsProvider.setPrefrence(ID, id!);
  //               settingsProvider.setPrefrence(MOBILE, mobile!);
  //
  //               Navigator.push(
  //                   context,
  //                   MaterialPageRoute(
  //                       builder: (context) => SendOtp(
  //                         title: getTranslated(context, 'FORGOT_PASS_TITLE'),
  //                       )));
  //             },
  //             child: Text(getTranslated(context, 'FORGOT_PASSWORD_LBL')!,
  //                 style: Theme.of(context).textTheme.subtitle2!.copyWith(
  //                     color: Theme.of(context).colorScheme.fontColor,
  //                     fontWeight: FontWeight.normal)),
  //           ),
  //         ],
  //       ));
  // }

  termAndPolicyTxt() {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
          bottom: 20.0, start: 25.0, end: 25.0, top: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(getTranslated(context, 'DONT_HAVE_AN_ACC')!,
              style: Theme.of(context).textTheme.caption!.copyWith(
                  color: Theme.of(context).colorScheme.fontColor,
                  fontWeight: FontWeight.normal,
                  fontSize: 16
              )),
          InkWell(
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (BuildContext context) =>
                      SendOtp(
                        checkForgot: "false",
                        title: getTranslated(context, 'SEND_OTP_TITLE'),
                      ),
                ));
              },
              child: Text(
                getTranslated(context, 'SIGN_UP_LBL')!,
                style: Theme.of(context).textTheme.caption!.copyWith(
                  color: colors.primary,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ))
        ],
      ),
    );
  }

  loginBtn() {
    return AppBtn(
      title: getTranslated(context, 'SIGNIN_LBL'),
      btnAnim: buttonSqueezeanimation,
      btnCntrl: buttonController,
      onBtnSelected: () async {
        validateAndSubmit();
      },
    );
  }

  _expandedBottomView() {
    return Expanded(
      flex: 6,
      child: Container(
        alignment: Alignment.bottomCenter,
        child: ScrollConfiguration(
            behavior: MyBehavior(),
            child: SingleChildScrollView(
              child: Form(
                key: _formkey,
                child: Card(
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  margin: EdgeInsetsDirectional.only(
                      start: 20.0, end: 20.0, top: 20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      signInTxt(),
                      setMobileNo(),
                      setPass(),
                      forgetPass(),
                      loginBtn(),
                      termAndPolicyTxt(),
                    ],
                  ),
                ),
              ),
            )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return
      Scaffold(
        resizeToAvoidBottomInset: false,
        key: _scaffoldKey,
        body: _isNetworkAvail
            ? Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: back(),
            ),
            Image.asset(
              'assets/images/doodle.png',
              fit: BoxFit.fill,
              width: double.infinity,
              height: double.infinity,
            ),
            getLoginContainer(),
            getLogo(),
          ],
        )
            : noInternet(context));
  }

  getLoginContainer() {
    return Positioned.directional(
      start: MediaQuery.of(context).size.width * 0.025,
      // end: width * 0.025,
      // top: width * 0.45,
      top: MediaQuery.of(context).size.height * 0.2, //original
      //    bottom: height * 0.1,
      textDirection: Directionality.of(context),
      child: ClipPath(
        clipper: ContainerClipper(),
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom * 0.8),
          height: MediaQuery.of(context).size.height * 0.7,
          width: MediaQuery.of(context).size.width * 0.95,
          color: Theme.of(context).colorScheme.white,
          child: Form(
            key: _formkey,
            child: ScrollConfiguration(
              behavior: MyBehavior(),
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 2,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.10,
                      ),
                      setSignInLabel(),
                      setMobileNo(),
                      setPass(),
                      forgetPass(),
                      loginBtn(),
                      SizedBox(height: 80,),
                      termAndPolicyTxt(),
                      // SizedBox(
                      //   height: MediaQuery.of(context).size.height * 0.10,
                      // ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget getLogo() {
  //   return Positioned(
  //     // textDirection: Directionality.of(context),
  //     left: (MediaQuery.of(context).size.width / 2) - 50,
  //     // right: ((MediaQuery.of(context).size.width /2)-55),
  //
  //     top: (MediaQuery.of(context).size.height * 0.2) - 50,
  //     //  bottom: height * 0.1,
  //     child: SizedBox(
  //       width: 100,
  //       height: 100,
  //       child: Image.asset(
  //         'assets/images/loginlogo.png',
  //       ),
  //     ),
  //   );
  // }
  Widget getLogo() {
    return Container(
      child: Positioned(
        left: (MediaQuery.of(context).size.width / 2) - 200,
        top: (MediaQuery.of(context).size.height * 0.2) - 100,
        child: SizedBox(
          width: 300,
          height: 150,
          child: ClipRRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: Image.asset(
                'assets/images/loginlogo.png',
              ),
            ),
          ),
        ),
      ),
    );
  }



  Widget setSignInLabel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          getTranslated(context, 'SIGNIN_LBL')!,
          style: const TextStyle(
            color: colors.primary,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
