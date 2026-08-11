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
  String get navStorage => 'Bộ nhớ';

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
  String get openFileOrFolder => 'Mở tệp hoặc thư mục';

  @override
  String get addShareTitle => 'Thêm SMB, WebDAV hoặc NFS';

  @override
  String get addShareSubtitle => 'Hoặc quét mạng nội bộ';

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
  String get back10 => 'Lùi 10 giây';

  @override
  String get forward30 => 'Tiến 30 giây';

  @override
  String get nothingToPlay =>
      'Chưa có gì để phát — hãy chọn tệp từ tab Bộ nhớ.';

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
