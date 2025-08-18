// Part of the GetX routing system.
// This abstract class holds the route names as static constants.
abstract class Routes {
  static const HOME = Paths.HOME;
  static const GAME = Paths.GAME;
  static const TODO = Paths.TODO;
}

// This abstract class is used to avoid typos by defining route paths.
abstract class Paths {
  static const HOME = '/home';
  static const GAME = '/game';
  static const TODO = '/todo';
}
