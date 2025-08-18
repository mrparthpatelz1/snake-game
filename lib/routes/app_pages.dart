import 'package:get/get.dart';
import '../modules/game/game_bindings.dart';
import '../modules/game/home/home_bindings.dart';
import '../modules/game/home/home_screen.dart';
import '../modules/game/views/game_screen.dart';
import 'app_routes.dart';

// This class manages the app's pages and their bindings.
class AppPages {
  // The initial route when the app starts.
  static const INITIAL = Routes.HOME;

  // A list of all the pages (GetPage) the app can navigate to.
  static final routes = [
    GetPage(
      name: Paths.HOME,
      page: () => const HomeScreen(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: Paths.GAME,
      page: () => const GameScreen(),
      binding: GameBinding(), // Binds the necessary controllers for the GameScreen.
    ),
  ];
}
