import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mother_story.dart';

final motherStoryRepositoryProvider = Provider<MotherStoryRepository>(
  (ref) => MotherStoryRepository(),
);

final motherStoriesProvider = FutureProvider<List<MotherStory>>((ref) {
  return ref.watch(motherStoryRepositoryProvider).loadStories();
});

class MotherStoryRepository {
  MotherStoryRepository({
    AssetBundle? assetBundle,
    this.assetPath = 'assets/fixtures/mother-stories.json',
  }) : assetBundle = assetBundle ?? rootBundle;

  final AssetBundle assetBundle;
  final String assetPath;

  Future<List<MotherStory>> loadStories() async {
    final source = await assetBundle.loadString(assetPath);
    final decoded = jsonDecode(source);
    if (decoded is! List<Object?>) {
      throw const FormatException('Mother stories fixture must be a list.');
    }

    final stories = decoded
        .map((item) {
          if (item is! Map<String, Object?>) {
            throw const FormatException(
              'Mother story entry must be an object.',
            );
          }
          return MotherStory.fromJson(item);
        })
        .toList(growable: false);

    final ids = stories.map((story) => story.id).toSet();
    if (ids.length != stories.length) {
      throw const FormatException('Mother story IDs must be unique.');
    }
    return stories;
  }
}
