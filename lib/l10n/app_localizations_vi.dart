// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'mPlayer';

  @override
  String get navStorage => 'Tệp';

  @override
  String get navServer => 'Máy chủ';

  @override
  String get navSearch => 'Tìm kiếm';

  @override
  String get settings => 'Cài đặt';

  @override
  String get actionCancel => 'Huỷ';

  @override
  String get actionSave => 'Lưu';

  @override
  String get actionTest => 'Kiểm tra';

  @override
  String get actionConnect => 'Kết nối';

  @override
  String get actionRetry => 'Thử lại';

  @override
  String get actionAdd => 'Thêm';

  @override
  String get actionClear => 'Xoá';

  @override
  String get actionBack => 'Quay lại';

  @override
  String get actionMore => 'Thêm nữa';

  @override
  String get actionSort => 'Sắp xếp';

  @override
  String get actionRefresh => 'Tải lại';

  @override
  String get actionRemove => 'Gỡ bỏ';

  @override
  String get viewList => 'Dạng danh sách';

  @override
  String get viewGrid => 'Dạng lưới';

  @override
  String notImplemented(String feature) {
    return '$feature — chưa hỗ trợ';
  }

  @override
  String get continueWatching => 'Xem tiếp';

  @override
  String get thisDevice => 'Thiết bị này';

  @override
  String get network => 'Mạng';

  @override
  String get openFile => 'Mở tệp';

  @override
  String get selectMore => 'Chọn thêm';

  @override
  String get partialAccessNotice => 'Chỉ hiện những video bạn đã chia sẻ.';

  @override
  String get noVideosOnDevice => 'Chưa tìm thấy video nào trên thiết bị này.';

  @override
  String get mediaAccessTitle => 'Cho phép mPlayer tìm video của bạn';

  @override
  String get mediaAccessBody =>
      'Android không cho ứng dụng duyệt bộ nhớ trực tiếp, nên chỉ mục media của hệ thống được dùng thay thế.';

  @override
  String videoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count video',
    );
    return '$_temp0';
  }

  @override
  String get addShareTitle => 'Thêm SMB hoặc WebDAV';

  @override
  String get addShareSubtitle => 'Một chia sẻ trong mạng của bạn';

  @override
  String driverUnavailable(String kind) {
    return '$kind — chưa có trình điều khiển';
  }

  @override
  String get shareOptions => 'Tuỳ chọn chia sẻ';

  @override
  String get removeShare => 'Gỡ chia sẻ';

  @override
  String get removeShareSubtitle => 'Mật khẩu đã lưu cũng bị xoá';

  @override
  String get addShareHeading => 'Thêm chia sẻ';

  @override
  String get fieldName => 'Tên';

  @override
  String get fieldAddress => 'Địa chỉ';

  @override
  String get fieldUsername => 'Tên đăng nhập';

  @override
  String get fieldPassword => 'Mật khẩu';

  @override
  String get anonymousHint => 'Để trống nếu chia sẻ không cần đăng nhập';

  @override
  String get showPassword => 'Hiện mật khẩu';

  @override
  String get hidePassword => 'Ẩn mật khẩu';

  @override
  String noDriverNotice(String kind) {
    return '$kind chưa có trình điều khiển. Chia sẻ vẫn được lưu và hiển thị, nhưng chưa duyệt được.';
  }

  @override
  String connectionOk(int folders, int files) {
    return 'Đã kết nối — $folders thư mục, $files tệp';
  }

  @override
  String folderCounts(int folders, int files) {
    return '$folders thư mục · $files tệp';
  }

  @override
  String get reading => 'Đang đọc…';

  @override
  String get directPlay => 'Phát trực tiếp';

  @override
  String get folder => 'Thư mục';

  @override
  String get emptyFolder => 'Thư mục này trống';

  @override
  String get couldNotReadFolder => 'Không đọc được thư mục này.';

  @override
  String notAVideo(String name) {
    return '$name không phải tệp video';
  }

  @override
  String get noServerTitle => 'Chưa có máy chủ nào';

  @override
  String get noServerBody =>
      'Mọi thứ trên thiết bị và các chia sẻ mạng đều hoạt động mà không cần máy chủ. Thêm máy chủ Jellyfin để đồng bộ tiến độ xem, siêu dữ liệu và truy cập từ xa.';

  @override
  String get addJellyfinServer => 'Thêm máy chủ Jellyfin';

  @override
  String get scanNetwork => 'Quét mạng này';

  @override
  String get otherServersNotice =>
      'Máy chủ Emby và Plex cũng thêm được ở đây — tab này không chỉ dành cho Jellyfin.';

  @override
  String get previewConnectedServer => 'Xem thử máy chủ đã kết nối';

  @override
  String get addServerHeading => 'Thêm máy chủ';

  @override
  String get serverAddress => 'Địa chỉ máy chủ';

  @override
  String get detectHint => 'Nhập địa chỉ để nhận diện máy chủ';

  @override
  String get detectPending =>
      'Việc nhận diện sẽ hoạt động khi có Jellyfin client';

  @override
  String get quickConnect => 'Dùng Quick Connect';

  @override
  String get quickConnectSubtitle => 'Duyệt từ một thiết bị đã đăng nhập khác';

  @override
  String get nextUp => 'Tiếp theo';

  @override
  String get recentlyAdded => 'Mới thêm';

  @override
  String get libraries => 'Thư viện';

  @override
  String get tabMovies => 'Phim lẻ';

  @override
  String get settingsAdmin => 'Quản trị máy chủ';

  @override
  String get justNow => 'vừa xong';

  @override
  String minutesAgo(int count) {
    return '$count phút trước';
  }

  @override
  String hoursAgo(int count) {
    return '$count giờ trước';
  }

  @override
  String daysAgo(int count) {
    return '$count ngày trước';
  }

  @override
  String get settingsAdminSub => 'Phiên phát, tác vụ, người dùng, plugin';

  @override
  String get adminTitle => 'Quản trị';

  @override
  String get adminNotAdmin => 'Tài khoản này không phải quản trị viên.';

  @override
  String get adminNoServer => 'Hãy đăng nhập vào một máy chủ trước.';

  @override
  String get adminServerSection => 'Máy chủ';

  @override
  String get adminSessions => 'Phiên đang hoạt động';

  @override
  String get adminNoSessions => 'Không có ai đang kết nối.';

  @override
  String get adminIdleSession => 'Đã kết nối, chưa phát gì';

  @override
  String get adminStopPlayback => 'Dừng phát';

  @override
  String get adminSendMessage => 'Gửi tin nhắn';

  @override
  String adminMessageTitle(String device) {
    return 'Nhắn tới $device';
  }

  @override
  String get adminMessageHint => 'Nội dung tin nhắn?';

  @override
  String get adminMessageSent => 'Đã gửi tin nhắn.';

  @override
  String get adminPlaybackStopped => 'Đã dừng phát.';

  @override
  String get adminTasks => 'Tác vụ theo lịch';

  @override
  String get adminNoTasks => 'Máy chủ này không liệt kê tác vụ nào.';

  @override
  String get adminRunTask => 'Chạy ngay';

  @override
  String get adminStopTask => 'Dừng';

  @override
  String adminTaskStarted(String name) {
    return 'Đã bắt đầu $name.';
  }

  @override
  String adminTaskStopping(String name) {
    return 'Đang dừng $name.';
  }

  @override
  String get adminTaskNeverRun => 'Chưa chạy lần nào';

  @override
  String adminTaskLastRun(String when) {
    return 'Chạy lần cuối $when';
  }

  @override
  String get adminTaskLastFailed => 'Lần chạy trước thất bại';

  @override
  String get adminScanLibraries => 'Quét toàn bộ thư viện';

  @override
  String get adminScanStarted => 'Đã bắt đầu quét thư viện.';

  @override
  String get adminUsers => 'Người dùng';

  @override
  String get adminNoUsers => 'Máy chủ này chưa có tài khoản nào.';

  @override
  String get adminUserAdmin => 'Quản trị viên';

  @override
  String get adminUserDisabled => 'Đã tắt';

  @override
  String get adminUserEnable => 'Bật';

  @override
  String get adminUserDisable => 'Tắt';

  @override
  String adminUserEnabled(String name) {
    return '$name đã có thể đăng nhập lại.';
  }

  @override
  String adminUserNowDisabled(String name) {
    return '$name không đăng nhập được nữa.';
  }

  @override
  String get adminDevices => 'Thiết bị';

  @override
  String get adminNoDevices => 'Chưa có thiết bị nào đăng nhập.';

  @override
  String get adminForgetDevice => 'Quên thiết bị này';

  @override
  String get adminDeviceForgotten => 'Đã quên thiết bị.';

  @override
  String get adminActivity => 'Nhật ký hoạt động';

  @override
  String get adminNoActivity => 'Chưa có gì được ghi lại.';

  @override
  String get adminPlugins => 'Plugin';

  @override
  String get adminNoPlugins => 'Chưa cài plugin nào.';

  @override
  String get adminPluginEnable => 'Bật';

  @override
  String get adminPluginDisable => 'Tắt';

  @override
  String get adminPluginUninstall => 'Gỡ cài đặt';

  @override
  String get adminPluginRestartPending => 'Cần khởi động lại';

  @override
  String get adminPluginBroken => 'Không hoạt động';

  @override
  String get adminPluginSuperceded => 'Đã có bản thay thế';

  @override
  String get adminPluginUnsupported => 'Không được hỗ trợ';

  @override
  String adminPluginChanged(String name) {
    return 'Đã cập nhật $name. Một số thay đổi cần khởi động lại.';
  }

  @override
  String adminPluginRemoved(String name) {
    return 'Đã gỡ $name.';
  }

  @override
  String adminUninstallPluginQuestion(String name) {
    return 'Gỡ $name?';
  }

  @override
  String get adminUninstallPluginBody =>
      'Cấu hình của nó vẫn nằm trên máy chủ, nhưng nó ngừng hoạt động cho tới khi được cài lại.';

  @override
  String get adminRename => 'Đổi tên máy chủ';

  @override
  String get adminRenameHint => 'Tên máy chủ';

  @override
  String get adminRenamed => 'Đã đổi tên máy chủ.';

  @override
  String get adminRestart => 'Khởi động lại máy chủ';

  @override
  String adminRestartQuestion(String name) {
    return 'Khởi động lại $name?';
  }

  @override
  String get adminRestartBody =>
      'Mọi người đang xem sẽ bị ngắt. Máy chủ sẽ tự chạy lại.';

  @override
  String get adminRestarting => 'Đã yêu cầu khởi động lại.';

  @override
  String get adminShutdown => 'Tắt máy chủ';

  @override
  String adminShutdownQuestion(String name) {
    return 'Tắt $name?';
  }

  @override
  String get adminShutdownBody =>
      'Mọi người đang xem sẽ bị ngắt, và không có gì ở đây bật lại được - phải có người bật trực tiếp tại máy.';

  @override
  String get adminShuttingDown => 'Đã yêu cầu tắt máy chủ.';

  @override
  String get adminCannotRestart => 'Máy chủ này không tự khởi động lại được.';

  @override
  String get actionSend => 'Gửi';

  @override
  String get actionRun => 'Chạy';

  @override
  String get tabShows => 'Phim bộ';

  @override
  String get tabItems => 'Tất cả';

  @override
  String get tabSuggestions => 'Gợi ý';

  @override
  String get tabFavourites => 'Yêu thích';

  @override
  String get tabCollections => 'Bộ sưu tập';

  @override
  String get tabPlaylists => 'Danh sách phát';

  @override
  String get noFavourites =>
      'Chưa có mục nào được đánh dấu trong thư viện này.';

  @override
  String get noCollections => 'Không có bộ sưu tập nào lấy từ thư viện này.';

  @override
  String get noPlaylists => 'Máy chủ này chưa có danh sách phát nào.';

  @override
  String get noSuggestions =>
      'Chưa có gì để gợi ý — xem gì đó rồi quay lại nhé.';

  @override
  String get emptyPlaylist => 'Danh sách phát này trống.';

  @override
  String becauseYouWatched(String title) {
    return 'Vì bạn đã xem $title';
  }

  @override
  String becauseYouLike(String title) {
    return 'Vì bạn thích $title';
  }

  @override
  String directedBy(String name) {
    return 'Đạo diễn bởi $name';
  }

  @override
  String starring(String name) {
    return 'Có sự tham gia của $name';
  }

  @override
  String get suggestedForYou => 'Gợi ý cho bạn';

  @override
  String itemCount(int count) {
    return '$count mục';
  }

  @override
  String get unwatched => 'Chưa xem';

  @override
  String unwatchedCount(int count) {
    return '$count chưa xem';
  }

  @override
  String get genre => 'Thể loại';

  @override
  String get filters => 'Bộ lọc';

  @override
  String get cast => 'Diễn viên';

  @override
  String get more => 'Thêm';

  @override
  String get less => 'Thu gọn';

  @override
  String get play => 'Phát';

  @override
  String get pause => 'Tạm dừng';

  @override
  String get download => 'Tải xuống';

  @override
  String get bookmark => 'Đánh dấu';

  @override
  String get searchEverything => 'Tìm mọi thứ';

  @override
  String get voiceSearch => 'Tìm bằng giọng nói';

  @override
  String get recentSearches => 'Tìm kiếm gần đây';

  @override
  String get whereToLook => 'Tìm ở đâu';

  @override
  String get allSources => 'Mọi nguồn';

  @override
  String get backToSources => 'Quay lại danh sách nguồn';

  @override
  String showMoreFrom(int count, String source) {
    return 'Xem thêm $count kết quả từ $source';
  }

  @override
  String get downloads => 'Tải xuống';

  @override
  String get nothingDownloaded => 'Chưa tải gì';

  @override
  String get downloadsBody =>
      'Mặc định chỉ tải khi có Wi-Fi và sẽ hết hạn theo chính sách của máy chủ.';

  @override
  String get pauseDownload => 'Tạm dừng';

  @override
  String get cancelDownload => 'Huỷ';

  @override
  String get availableOffline => 'Xem được ngoại tuyến';

  @override
  String get settingsAppearance => 'Giao diện';

  @override
  String get settingsAppearanceSub => 'Chủ đề, màu nhấn, mật độ';

  @override
  String get settingsGeneral => 'Chung';

  @override
  String get settingsGeneralSub => 'Ngôn ngữ, tab khởi động, bộ nhớ đệm';

  @override
  String get settingsPlayer => 'Trình phát';

  @override
  String get settingsPlayerSub => 'Giải mã, cử chỉ, chất lượng phát';

  @override
  String get settingsAudio => 'Âm thanh';

  @override
  String get settingsAudioSub => 'Passthrough, ngôn ngữ, tăng âm';

  @override
  String get settingsSubtitle => 'Phụ đề';

  @override
  String get settingsSubtitleSub => 'Kiểu chữ, thứ tự ngôn ngữ, độ trễ';

  @override
  String get settingsAbout => 'Giới thiệu';

  @override
  String get settingsAboutSub => 'Phiên bản, giấy phép, chẩn đoán';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get languageSystem => 'Theo hệ thống';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageVietnamese => 'Tiếng Việt';

  @override
  String get theme => 'Chủ đề';

  @override
  String get themeLight => 'Sáng';

  @override
  String get themeDark => 'Tối';

  @override
  String get themeSystem => 'Hệ thống';

  @override
  String get accent => 'Màu nhấn';

  @override
  String get dynamicColour => 'Màu động Material You';

  @override
  String get dynamicColourSub => 'Theo bảng màu hình nền hệ thống';

  @override
  String get pureBlack => 'Đen tuyền ở chế độ tối';

  @override
  String get pureBlackSub => 'Tiết kiệm pin trên màn hình OLED';

  @override
  String get layout => 'Bố cục';

  @override
  String get defaultLibraryView => 'Kiểu xem thư viện mặc định';

  @override
  String get density => 'Mật độ';

  @override
  String get playback => 'Phát lại';

  @override
  String get hardwareDecoding => 'Giải mã phần cứng';

  @override
  String get hardwareDecodingValue => 'Tự động (an toàn)';

  @override
  String get hardwareDecodingSub =>
      'Tự chuyển sang phần mềm khi codec không được hỗ trợ';

  @override
  String get resumeBehaviour => 'Cách tiếp tục xem';

  @override
  String get skipBack => 'Tua lùi';

  @override
  String get skipForward => 'Tua tới';

  @override
  String get autoPlayNext => 'Tự phát tập tiếp theo';

  @override
  String get autoSkipIntro => 'Tự bỏ qua intro';

  @override
  String get autoSkipIntroSub => 'Chỉ khi máy chủ đánh dấu chương intro';

  @override
  String get serverSegments => 'Phân đoạn từ máy chủ';

  @override
  String get serverSegmentsSub =>
      'Cần làm gì khi máy chủ Jellyfin đánh dấu một phần của tập phim';

  @override
  String get segmentIntro => 'Nhạc mở đầu';

  @override
  String get segmentOutro => 'Credit cuối phim';

  @override
  String get segmentRecap => 'Tóm tắt tập trước';

  @override
  String get segmentPreview => 'Giới thiệu tập sau';

  @override
  String get segmentCommercial => 'Quảng cáo';

  @override
  String get segmentActionNothing => 'Không làm gì';

  @override
  String get segmentActionAsk => 'Hỏi trước khi bỏ qua';

  @override
  String get segmentActionSkip => 'Tự động bỏ qua';

  @override
  String get screenAndGestures => 'Màn hình & cử chỉ';

  @override
  String get rotation => 'Xoay màn hình';

  @override
  String get rotationFollowVideo => 'Theo video';

  @override
  String get swipeGestures => 'Cử chỉ vuốt';

  @override
  String get swipeGesturesSub => 'Độ sáng bên trái, âm lượng bên phải';

  @override
  String get backgroundPip => 'Chạy nền & picture-in-picture';

  @override
  String get streamingQuality => 'Chất lượng phát trực tuyến';

  @override
  String get onWifi => 'Khi dùng Wi-Fi';

  @override
  String get onCellular => 'Khi dùng dữ liệu di động';

  @override
  String get original => 'Nguyên bản';

  @override
  String megabitsPerSecond(int value) {
    return '$value Mbps';
  }

  @override
  String get style => 'Kiểu hiển thị';

  @override
  String get font => 'Phông chữ';

  @override
  String get textSize => 'Cỡ chữ';

  @override
  String get backgroundOpacity => 'Độ mờ nền';

  @override
  String get behaviour => 'Hành vi';

  @override
  String get preferredLanguages => 'Ngôn ngữ ưu tiên';

  @override
  String get burnInWhenTranscoding => 'Ghi đè vào hình khi chuyển mã';

  @override
  String get burnInSub => 'Chỉ với phụ đề dạng ảnh';

  @override
  String get syncOffset => 'Độ lệch đồng bộ';

  @override
  String get subtitlePreview => 'Thuỷ triều đổi chiều lúc nửa đêm.';

  @override
  String percent(int value) {
    return '$value%';
  }

  @override
  String versionAndBuild(String version, String build) {
    return 'Phiên bản $version · bản dựng $build';
  }

  @override
  String get upToDate => 'Đã là mới nhất';

  @override
  String get checkForUpdates => 'Kiểm tra cập nhật';

  @override
  String get releaseNotes => 'Ghi chú phát hành';

  @override
  String get diagnostics => 'Chẩn đoán';

  @override
  String get openSourceLicences => 'Giấy phép mã nguồn mở';

  @override
  String get privacy => 'Quyền riêng tư';

  @override
  String get sourceCode => 'Mã nguồn';

  @override
  String get thisDeviceInfo => 'Thiết bị này';

  @override
  String get notAffiliated =>
      'mPlayer không liên kết, không được bảo trợ hay tài trợ bởi các dự án Jellyfin, Emby hay Plex.';

  @override
  String get subtitles => 'Phụ đề';

  @override
  String get audio => 'Âm thanh';

  @override
  String get quality => 'Chất lượng';

  @override
  String get playbackSpeed => 'Tốc độ phát';

  @override
  String get chapters => 'Chương';

  @override
  String get noChapters => 'Tệp này không có chương';

  @override
  String get off => 'Tắt';

  @override
  String get auto => 'Tự động';

  @override
  String get normal => 'Bình thường';

  @override
  String get defaultLabel => 'Mặc định';

  @override
  String get skipIntro => 'Bỏ qua intro';

  @override
  String get skipCredits => 'Bỏ qua credit';

  @override
  String get skipRecap => 'Bỏ qua tóm tắt';

  @override
  String get skipPreview => 'Bỏ qua giới thiệu';

  @override
  String get skipAdvert => 'Bỏ qua quảng cáo';

  @override
  String get lockPlayer => 'Khoá trình phát';

  @override
  String get screenLocked => 'Đã khoá màn hình';

  @override
  String get unlockHint => 'Chạm hai lần vào ổ khoá để mở';

  @override
  String get fullscreen => 'Toàn màn hình';

  @override
  String get pictureInPicture => 'Picture-in-picture';

  @override
  String get castTo => 'Truyền';

  @override
  String get aspectRatio => 'Tỉ lệ khung hình';

  @override
  String get aspectFit => 'Vừa khung';

  @override
  String get aspectFill => 'Lấp đầy';

  @override
  String get aspectStretch => 'Kéo giãn';

  @override
  String get sleepTimer => 'Hẹn giờ tắt';

  @override
  String minutes(int count) {
    return '$count phút';
  }

  @override
  String get statsForNerds => 'Thông số kỹ thuật';

  @override
  String get playerSettings => 'Cài đặt trình phát';

  @override
  String get on => 'Bật';

  @override
  String back10(int seconds) {
    return 'Lùi $seconds giây';
  }

  @override
  String forward30(int seconds) {
    return 'Tiến $seconds giây';
  }

  @override
  String get nothingToPlay => 'Chưa có gì để phát — hãy chọn tệp từ tab Tệp.';

  @override
  String get previousFile => 'Trước';

  @override
  String get nextFile => 'Tiếp';

  @override
  String get nextEpisode => 'Tập tiếp theo';

  @override
  String get nextVideo => 'Video tiếp theo';

  @override
  String get loading => 'Đang tải';

  @override
  String aspectRatioValue(String mode) {
    return 'Tỉ lệ khung hình: $mode';
  }

  @override
  String rotationValue(String mode) {
    return 'Xoay: $mode';
  }

  @override
  String subtitlesValue(String track) {
    return 'Phụ đề: $track';
  }

  @override
  String audioValue(String track) {
    return 'Âm thanh: $track';
  }

  @override
  String speedValue(String speed) {
    return 'Tốc độ: $speed×';
  }

  @override
  String get audioDelay => 'Độ trễ âm thanh';

  @override
  String get openSubtitleFile => 'Mở tệp phụ đề…';

  @override
  String get playOn => 'Phát trên';

  @override
  String get searchAgain => 'Tìm lại';

  @override
  String get noDevicesFound =>
      'Không tìm thấy thiết bị nào. Kiểm tra TV đã bật và cùng mạng với điện thoại.';

  @override
  String get stopCasting => 'Dừng truyền';

  @override
  String playingOn(String device) {
    return 'Đang phát trên $device';
  }

  @override
  String get couldNotCast => 'Không truyền được tới thiết bị đó.';

  @override
  String get grantedFolder => 'Thư mục đã cấp quyền';

  @override
  String get removeFolder => 'Gỡ thư mục';

  @override
  String get addFolder => 'Thêm thư mục';

  @override
  String get addFolderSubtitle => 'Cho video mà chỉ mục media không liệt kê';

  @override
  String get allowAccess => 'Cho phép truy cập';

  @override
  String get editShare => 'Sửa chia sẻ';

  @override
  String get editShareSubtitle => 'Đổi tên, địa chỉ hoặc thông tin đăng nhập';

  @override
  String get hardwareDecodingFallback =>
      'Tự chuyển sang phần mềm khi codec không được hỗ trợ';

  @override
  String get audioDelaySub => 'Dịch tiếng so với hình';

  @override
  String get autoPlayNextSub => 'Phát tiếp video kế trong thư mục';

  @override
  String get pictureInPictureSub =>
      'Thu thành cửa sổ nổi khi bạn rời khỏi ứng dụng';

  @override
  String get backgroundAudio => 'Phát tiếng ở nền';

  @override
  String get backgroundAudioSub =>
      'Vẫn phát khi tắt màn hình, kèm thông báo điều khiển';

  @override
  String get followVideo => 'Theo video';

  @override
  String get needsTranscodingServer => 'Cần máy chủ có khả năng chuyển mã';

  @override
  String get noPreference => 'Không ưu tiên';

  @override
  String get noPreferenceSub => 'Giữ nguyên track mà tệp đã chọn';

  @override
  String get preferredLanguage => 'Ngôn ngữ ưu tiên';

  @override
  String get preferredLanguageSub => 'Ngôn ngữ bạn muốn nghe và đọc';

  @override
  String get smartSubtitles => 'Phụ đề thông minh';

  @override
  String get smartSubtitlesSub => 'Chỉ bật phụ đề khi tiếng là ngôn ngữ khác';

  @override
  String get imageBasedOnly => 'Chỉ với phụ đề dạng ảnh';

  @override
  String get syncOffsetSub => 'Số dương làm phụ đề chậm lại';

  @override
  String get subtitlePreviewLine => 'Thuỷ triều đổi chiều lúc nửa đêm.';

  @override
  String get grid => 'Lưới';

  @override
  String get comfortable => 'Thoải mái';

  @override
  String get audioOutput => 'Đầu ra';

  @override
  String get passthrough => 'Truyền thẳng bitstream';

  @override
  String get passthroughSub =>
      'Gửi AC3, DTS, E-AC3 và TrueHD sang ampli mà không giải mã';

  @override
  String get passthroughNote =>
      'Chỉ bật nếu có receiver hoặc soundbar giải mã hộ. Không có thì truyền thẳng sẽ ra im lặng.';

  @override
  String get volumeBoost => 'Tăng âm lượng';

  @override
  String get volumeBoostNote =>
      'Trần cho thao tác chỉnh âm lượng. Trên 100% tiếng được khuếch đại — cứu được phim nhỏ tiếng, nhưng phim to tiếng có thể bị rè.';

  @override
  String get gapless => 'Phát liền mạch';

  @override
  String get gaplessSub =>
      'Mức cố gắng nối tệp này sang tệp kế mà không có khoảng lặng';

  @override
  String get gaplessOff => 'Tắt';

  @override
  String get gaplessOffSub => 'Luôn khởi tạo lại giữa các tệp';

  @override
  String get gaplessAutomatic => 'Tự động';

  @override
  String get gaplessAutomaticSub => 'Liền mạch khi tệp kế cùng định dạng';

  @override
  String get gaplessAlways => 'Luôn luôn';

  @override
  String get gaplessAlwaysSub => 'Liền mạch kể cả khi phải lấy mẫu lại';

  @override
  String get tracks => 'Track';

  @override
  String get sharedWithSubtitles => 'Dùng chung với cài đặt Phụ đề';

  @override
  String get checkForUpdatesSub =>
      'Hỏi GitHub một lần. Không gửi gì về bạn hay thiết bị';

  @override
  String get diagnosticsSub =>
      'Bản dựng, thiết bị và log trình phát, để báo lỗi';

  @override
  String get privacySub => 'Cái gì rời khỏi máy này, và cái gì thì không';

  @override
  String get checking => 'Đang kiểm tra…';

  @override
  String updateAvailable(String version) {
    return 'Đã có bản $version';
  }

  @override
  String get couldNotCheck => 'Không kiểm tra được';

  @override
  String couldNotOpen(String url) {
    return 'Không mở được $url';
  }

  @override
  String get build => 'Bản dựng';

  @override
  String get version => 'Phiên bản';

  @override
  String get applicationId => 'Mã ứng dụng';

  @override
  String get platform => 'Nền tảng';

  @override
  String get operatingSystem => 'Hệ điều hành';

  @override
  String get locale => 'Ngôn ngữ hệ thống';

  @override
  String get screen => 'Màn hình';

  @override
  String get playerLog => 'Log trình phát';

  @override
  String get copyEverything => 'Sao chép tất cả';

  @override
  String get diagnosticsCopied => 'Đã sao chép thông tin chẩn đoán';

  @override
  String get logEmpty =>
      'Chưa có gì. Log chỉ đầy lên khi đang phát, và chỉ giữ trong phiên này.';

  @override
  String get privacyNoTelemetry =>
      'Không thống kê, không telemetry, không báo cáo sự cố';

  @override
  String get privacyNoTelemetryBody =>
      'Không có SDK bên thứ ba nào thu thập gì. mPlayer chỉ liên lạc với máy chủ và chia sẻ mà bạn tự cấu hình, ngoài ra không gì khác.';

  @override
  String get privacyLocal => 'Thư viện của bạn nằm lại trên máy';

  @override
  String get privacyLocalBody =>
      'Bạn xem gì, xem tới đâu và ảnh trên kệ Xem tiếp đều lưu cục bộ. Không thứ nào rời khỏi máy.';

  @override
  String get privacyKeychain => 'Mật khẩu nằm trong keychain của hệ thống';

  @override
  String get privacyKeychainBody =>
      'Thông tin đăng nhập chia sẻ và máy chủ đi vào bộ lưu trữ bảo mật của nền tảng, không bao giờ nằm chung với các cài đặt thường.';

  @override
  String get privacyUpdates => 'Kiểm tra cập nhật là thủ công';

  @override
  String get privacyUpdatesBody =>
      'Không kiểm tra gì lúc khởi động. Bấm \"Kiểm tra cập nhật\" mới gửi một yêu cầu ẩn danh tới API releases của GitHub — không kèm định danh nào.';

  @override
  String get privacyCasting =>
      'Truyền màn hình mở một máy chủ trong mạng của bạn';

  @override
  String get privacyCastingBody =>
      'Trong lúc truyền, tệp đang phát được phục vụ qua mạng nội bộ để TV lấy về. Máy chủ đó tắt ngay khi ngừng truyền.';

  @override
  String get privacyFooter =>
      'mPlayer là phần mềm tự do theo GPL-3.0-or-later. Bạn có thể đọc mã nguồn và tự kiểm chứng mọi điều trên trang này.';

  @override
  String get noChaptersInFile => 'Tệp này không có chương';

  @override
  String get locked => 'Đã khoá';

  @override
  String milliseconds(int count) {
    return '$count ms';
  }

  @override
  String seconds(int count) {
    return '$count giây';
  }

  @override
  String timeLeft(String time) {
    return 'còn $time';
  }

  @override
  String get cancel => 'Huỷ';

  @override
  String get create => 'Tạo';

  @override
  String get save => 'Lưu';

  @override
  String get addToPlaylist => 'Thêm vào danh sách phát';

  @override
  String get newPlaylist => 'Danh sách phát mới';

  @override
  String get playlistName => 'Tên';

  @override
  String get markWatched => 'Đánh dấu đã xem';

  @override
  String get markUnwatched => 'Đánh dấu chưa xem';

  @override
  String get addFavourite => 'Thêm vào yêu thích';

  @override
  String get removeFavourite => 'Bỏ khỏi yêu thích';

  @override
  String get shufflePlay => 'Phát ngẫu nhiên';

  @override
  String get downloadAll => 'Tải tất cả';

  @override
  String get mediaInfo => 'Thông tin media';

  @override
  String get startOver => 'Xem từ đầu';

  @override
  String get actionFailed => 'Máy chủ không thực hiện được.';

  @override
  String get audioTrack => 'Âm thanh';

  @override
  String get subtitleTrack => 'Phụ đề';

  @override
  String get subtitlesOff => 'Tắt';

  @override
  String get serverDefault => 'Mặc định của máy chủ';

  @override
  String get switchServer => 'Máy chủ';

  @override
  String get editServer => 'Sửa máy chủ';

  @override
  String get addServer => 'Thêm máy chủ';

  @override
  String get removeServer => 'Xoá máy chủ';

  @override
  String removeServerBody(Object name) {
    return '$name sẽ bị quên, cùng với thông tin đăng nhập. Không có gì trên máy chủ bị xoá.';
  }

  @override
  String get qualityOriginal => 'Gốc';

  @override
  String get qualityOriginalDetail =>
      'Không mã hoá lại. Hình đẹp nhất, và là lựa chọn duy nhất không phụ thuộc CPU máy chủ.';

  @override
  String get playbackQuality => 'Chất lượng phát';

  @override
  String episodeOf(int season, int episode) {
    return 'P${season}T$episode';
  }

  @override
  String signedInAs(String name) {
    return 'Đang đăng nhập bằng $name';
  }

  @override
  String get signInAgain => 'Phiên đã lưu vẫn dùng được';

  @override
  String get change => 'Đổi';

  @override
  String get noServersYet => 'Chưa có máy chủ nào.';

  @override
  String get username => 'Tên đăng nhập';

  @override
  String get password => 'Mật khẩu';

  @override
  String get quickConnectInstead => 'Dùng Quick Connect';

  @override
  String get quickConnectHint => 'Duyệt từ một thiết bị đã đăng nhập';

  @override
  String get connect => 'Kết nối';

  @override
  String get getACode => 'Lấy mã';

  @override
  String get enterCodeInJellyfin => 'Nhập mã này trong Jellyfin';

  @override
  String get serverTab => 'Máy chủ';

  @override
  String get searchThisServer => 'Tìm trong máy chủ này';

  @override
  String get nothingHere => 'Không có gì ở đây.';

  @override
  String get moreLikeThis => 'Phim tương tự';

  @override
  String get about => 'Giới thiệu';

  @override
  String get studios => 'Hãng sản xuất';

  @override
  String get seriesStatus => 'Trạng thái';

  @override
  String get statusContinuing => 'Đang chiếu';

  @override
  String get statusEnded => 'Đã kết thúc';

  @override
  String get gridSize => 'Cỡ lưới';

  @override
  String gridColumns(int count) {
    return '$count mỗi hàng';
  }

  @override
  String get sortName => 'A–Z';

  @override
  String get sortDateAdded => 'Mới thêm';

  @override
  String get sortReleaseDate => 'Ngày phát hành';

  @override
  String get sortDatePlayed => 'Mới xem';

  @override
  String get sortRandom => 'Ngẫu nhiên';

  @override
  String resumeAt(String time) {
    return 'Xem tiếp · $time';
  }

  @override
  String get watched => 'đã xem';

  @override
  String get episodeNew => 'mới';

  @override
  String seasonCount(int count) {
    return '$count mùa';
  }

  @override
  String episodeCount(int count) {
    return '$count tập';
  }

  @override
  String seasonNumber(int number) {
    return 'Mùa $number';
  }

  @override
  String get specials => 'Đặc biệt';

  @override
  String get kindMovie => 'Phim';

  @override
  String get kindSeries => 'Phim bộ';

  @override
  String get kindSeason => 'Mùa';

  @override
  String get kindEpisode => 'Tập';

  @override
  String get noResults => 'Không có kết quả nào';

  @override
  String get clearAll => 'Xoá hết';

  @override
  String get clearContinueWatchingTitle => 'Xoá kệ Xem tiếp?';

  @override
  String get clearContinueWatchingBody =>
      'Mọi vị trí đã lưu sẽ bị quên, chỉ trên máy này. Không xoá gì trên chia sẻ hay máy chủ của bạn.';

  @override
  String get continueWatchingCleared => 'Đã xoá kệ Xem tiếp';

  @override
  String get rotationAuto => 'Tự động';

  @override
  String get rotationLandscape => 'Ngang';

  @override
  String get rotationPortrait => 'Dọc';

  @override
  String get connected => 'Đã kết nối';

  @override
  String get offline => 'Ngoại tuyến';

  @override
  String get offlineSkipped => 'Ngoại tuyến — sẽ bỏ qua';
}
