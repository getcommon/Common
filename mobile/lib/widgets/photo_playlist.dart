import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/user_profile.dart';

/// An optional, swipeable six-photo reel for public profiles.
/// Tapping a frame opens the same reel in an immersive full-screen viewer.
class PhotoPlaylist extends StatefulWidget {
  const PhotoPlaylist({super.key, required this.moments, this.title});

  final List<ProfilePhotoMoment> moments;
  final String? title;

  @override
  State<PhotoPlaylist> createState() => _PhotoPlaylistState();
}

class _PhotoPlaylistState extends State<PhotoPlaylist> {
  late final PageController _controller;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: .84);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.moments.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title ?? 'A visual playlist',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Swipe through a few things that feel like me.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 13),
        SizedBox(
          height: 278,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.moments.length,
            padEnds: false,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemBuilder: (context, index) {
              final moment = widget.moments[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index == widget.moments.length - 1 ? 0 : 10,
                ),
                child: _PlaylistFrame(
                  moment: moment,
                  index: index,
                  count: widget.moments.length,
                  onTap: () => _openViewer(context, index),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.moments.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: index == _currentPage ? 18 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: index == _currentPage
                    ? AppColors.primary
                    : colors.outlineVariant,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openViewer(BuildContext context, int initialPage) {
    showDialog<void>(
      context: context,
      builder: (_) => _PlaylistViewer(
        moments: widget.moments,
        initialPage: initialPage,
      ),
    );
  }
}

class _PlaylistFrame extends StatelessWidget {
  const _PlaylistFrame({
    required this.moment,
    required this.index,
    required this.count,
    required this.onTap,
  });

  final ProfilePhotoMoment moment;
  final int index;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open photo ${index + 1} of $count',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    moment.photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _MissingPlaylistImage(),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x990D0908)],
                        stops: [.4, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Text(
                      '${index + 1} / $count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (moment.prompt != null && moment.prompt!.isNotEmpty)
                    Positioned(
                      left: 15,
                      right: 15,
                      bottom: 14,
                      child: Text(
                        moment.prompt!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistViewer extends StatefulWidget {
  const _PlaylistViewer({required this.moments, required this.initialPage});

  final List<ProfilePhotoMoment> moments;
  final int initialPage;

  @override
  State<_PlaylistViewer> createState() => _PlaylistViewerState();
}

class _PlaylistViewerState extends State<_PlaylistViewer> {
  late final PageController _controller;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _controller = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moment = widget.moments[_currentPage];
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.moments.length,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemBuilder: (_, index) => InteractiveViewer(
                minScale: 1,
                maxScale: 3,
                child: Center(
                  child: Image.network(
                    widget.moments[index].photoUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const _MissingPlaylistImage(),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: 'Close photo viewer',
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 25,
              child: Column(
                children: [
                  Text(
                    '${_currentPage + 1} of ${widget.moments.length}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (moment.prompt != null && moment.prompt!.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      moment.prompt!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingPlaylistImage extends StatelessWidget {
  const _MissingPlaylistImage();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Center(
      child: Icon(Icons.image_not_supported_outlined, color: AppColors.secondary),
    ),
  );
}
