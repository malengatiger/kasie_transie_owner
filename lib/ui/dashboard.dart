import 'package:flutter/material.dart';
import 'package:kasie_transie_library/bloc/data_api_dog.dart';
import 'package:kasie_transie_library/bloc/list_api_dog.dart';
import 'package:kasie_transie_library/data/big_bag.dart';
import 'package:kasie_transie_library/isolates/routes_isolate.dart';
import 'package:kasie_transie_library/messaging/fcm_bloc.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/data/schemas.dart' as lib;
import 'package:kasie_transie_library/l10n/translation_handler.dart';
import 'package:kasie_transie_library/utils/navigator_utils.dart';
import 'package:kasie_transie_library/utils/prefs.dart';
import 'package:kasie_transie_library/widgets/car_list.dart';
import 'package:kasie_transie_library/widgets/counts_widget.dart';
import 'package:kasie_transie_library/widgets/days_drop_down.dart';
import 'package:kasie_transie_library/widgets/language_and_color_chooser.dart';
import 'package:kasie_transie_library/widgets/number_widget.dart';
import 'package:kasie_transie_route_builder/ui/cellphone_auth_signin.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({Key? key}) : super(key: key);

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final mm = '🥬🥬🥬🥬🥬🥬 Dashboard: 😡';

  lib.User? user;
  BigBag? bigBag;
  bool busy = false;
  List<lib.Vehicle> cars = [];
  String? ownerDashboard,
      numberOfCars,
      arrivalsText,
      departuresText,
      heartbeatText,
      daysText,
      historyCars,
      dispatchesText;

  @override
  void initState() {
    super.initState();
    _initialize();
    _checkAuth();
    _setTexts();
  }

  void _initialize() async {
    fcmBloc.subscribeToTopics();

  }
  void _checkAuth() async {
    user = await prefs.getUser();
    if (user == null) {
      _navigateToSignIn();
    } else {
      _getData(false);
    }
  }

  void _setTexts() async {
    var c = await prefs.getColorAndLocale();
    numberOfCars = await translator.translate('numberOfCars', c.locale);
    arrivalsText = await translator.translate('arrivals', c.locale);
    departuresText = await translator.translate('departures', c.locale);
    heartbeatText = await translator.translate('heartbeats', c.locale);
    dispatchesText = await translator.translate('dispatches', c.locale);
    ownerDashboard = await translator.translate('ownerDash', c.locale);
    daysText = await translator.translate('days', c.locale);
    historyCars = await translator.translate('historyCars', c.locale);

    setState(() {});
  }

  void _navigateToSignIn() async {
    pp('$mm ... _navigateToSignIn ...');
    var res = await navigateWithScale(
        CellPhoneAuthSignin(dataApiDog: dataApiDog), context);
    pp('\n\nmm .... back from sign in : $res');
    _getData(false);
  }

  Future _getData(bool refresh) async {
    pp('$mm .... getting owner data ....');
    //todo - add feature to pick start date
    try {
      setState(() {
        busy = true;
      });
      user = await prefs.getUser();
      final date = DateTime.now().toUtc().subtract( Duration(days: days));
      cars = await listApiDog.getOwnerVehicles(user!.userId!, refresh);
      bigBag =
          await listApiDog.getOwnersBag(user!.userId!, date.toIso8601String());
    } catch (e) {
      pp(e);
    }
    setState(() {
      busy = false;
    });
  }

  Future<void> _navigateToCarList() async {
    var car = await navigateWithScale(
        CarList(
          ownerId: user!.userId,
        ),
        context);
    pp('$mm .... back from car list');
  }

  void _navigateToColor() async {
    pp('$mm navigate to color ...');
    await navigateWithScale(const LanguageAndColorChooser(), context);
    _setTexts();
  }

  int days = 14;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
      appBar: AppBar(
        title: Text(
          ownerDashboard == null ? 'Owner Dashboard' : ownerDashboard!,
          style: myTextStyleMediumLarge(context, 24),
        ),
        actions: [
          IconButton(
              onPressed: () {
                _navigateToColor();
              },
              icon: Icon(
                Icons.color_lens,
                color: Theme.of(context).primaryColor,
              )),
          IconButton(
              onPressed: () {
                _getData(true);
              },
              icon: Icon(Icons.refresh, color: Theme.of(context).primaryColor)),
        ],
      ),
      body: busy
          ? const Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 6,
                  backgroundColor: Colors.pink,
                ),
              ),
            )
          : Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Card(
                    shape: getRoundedBorder(radius: 16),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              _navigateToCarList();
                            },
                            child: Card(
                              shape: getRoundedBorder(radius: 16),
                              elevation: 6,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      height: 64,
                                    ),
                                    Text(numberOfCars == null
                                        ? 'Number of Cars'
                                        : numberOfCars!),
                                    const SizedBox(
                                      width: 12,
                                    ),
                                    Text(
                                      '${cars.length}',
                                      style: myTextStyleMediumLargeWithColor(
                                          context,
                                          Theme.of(context).primaryColor,
                                          36),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          user == null
                              ? const Text('....')
                              : Text(
                                  user!.name,
                                  style: myTextStyleSmall(context),
                                ),
                          const SizedBox(
                            height: 64,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(historyCars == null?
                                'History for all cars':historyCars!,
                                style: myTextStyleMedium(context),
                              ),
                              const SizedBox(
                                width: 4,
                              ),
                              Text(
                                '$days',
                                style: myTextStyleMediumLargeWithColor(context,
                                    Theme.of(context).primaryColor, 24),
                              ),
                              const SizedBox(
                                width: 12,
                              ),
                              DaysDropDown(
                                  onDaysPicked: (d) {
                                    setState(() {
                                      days = d;
                                    });
                                    _getData(true);
                                  },
                                  hint: daysText == null? 'Days' : daysText!),
                            ],
                          ),
                          const SizedBox(
                            height: 48,
                          ),
                          bigBag == null
                              ? const SizedBox()
                              : Expanded(
                                  child: CountsGridWidget(
                                    arrivalsText: arrivalsText!,
                                    departuresText: departuresText!,
                                    dispatchesText: dispatchesText!,
                                    heartbeatText: heartbeatText!,
                                    arrivals: bigBag!.vehicleArrivals.length,
                                    departures:
                                        bigBag!.vehicleDepartures.length,
                                    heartbeats:
                                        bigBag!.vehicleHeartbeats.length,
                                    dispatches: bigBag!.dispatchRecords.length,
                                  ),
                                )
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),
    ));
  }
}
