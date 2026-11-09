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
  String get navSearch => 'Tìm kiếm';

  @override
  String get navHome => 'Trang chủ';

  @override
  String get tabBrowse => 'Duyệt';

  @override
  String recentlyAddedIn(String library) {
    return 'Mới thêm vào $library';
  }

  @override
  String get customizeHome => 'Tùy chỉnh trang chủ';

  @override
  String get refresh => 'Làm mới';

  @override
  String get customizeHomeSub =>
      'Chọn thư viện nào hiện nội dung mới nhất. Được lưu vào tài khoản của bạn trên máy chủ, nên ứng dụng web cũng hiển thị giống vậy.';

  @override
  String get changeServer => 'Đổi máy chủ';

  @override
  String get chooseServerFirst => 'Hãy mở một máy chủ từ tab Trang chủ trước.';

  @override
  String get settingsSectionApp => 'Cài đặt ứng dụng';

  @override
  String get settingsSectionServer => 'Cài đặt máy chủ';

  @override
  String get noDownloads => 'Chưa tải xuống gì';

  @override
  String get settings => 'Cài đặt';

  @override
  String get actionCancel => 'Huỷ';

  @override
  String get actionSave => 'Lưu';

  @override
  String get actionConnect => 'Kết nối';

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
  String driverUnavailable(String kind) {
    return '$kind — chưa có trình điều khiển';
  }

  @override
  String get addShareHeading => 'Thêm chia sẻ';

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
  String get noServerTitle => 'Chưa có máy chủ nào';

  @override
  String get noServerBody =>
      'mPlayer phát nội dung từ máy chủ media. Thêm một máy chủ Jellyfin để duyệt thư viện, đồng bộ tiến độ xem giữa các thiết bị và truy cập từ bất cứ đâu.';

  @override
  String get addJellyfinServer => 'Thêm máy chủ Jellyfin';

  @override
  String get scanNetwork => 'Quét mạng này';

  @override
  String get otherServersNotice =>
      'mPlayer dùng với máy chủ Jellyfin. Emby và Plex không được hỗ trợ.';

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
  String get favourites => 'Yêu thích';

  @override
  String get seeAll => 'Xem tất cả';

  @override
  String get onThisDevice => 'Lưu trên thiết bị này';

  @override
  String get noFavouritesYet =>
      'Chưa có mục yêu thích nào. Bấm biểu tượng trái tim trên một phim, series hoặc tập phim để thêm vào đây.';

  @override
  String get recentlyAdded => 'Mới thêm';

  @override
  String get libraries => 'Thư viện';

  @override
  String get switchLibrary => 'Chuyển thư viện';

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
  String get renameServerLocal =>
      'Chỉ trên thiết bị này. Máy chủ và các ứng dụng khác vẫn giữ tên hiện tại. Để trống để dùng tên của máy chủ.';

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
  String get adminUserYou => 'Bạn';

  @override
  String get adminAddUser => 'Thêm người dùng';

  @override
  String get adminNewUserTitle => 'Người dùng mới';

  @override
  String get adminUserNameLabel => 'Tên';

  @override
  String get adminPasswordOptional => 'Mật khẩu (không bắt buộc)';

  @override
  String get adminCreate => 'Tạo';

  @override
  String adminUserCreated(String name) {
    return 'Đã tạo $name.';
  }

  @override
  String get adminSetPassword => 'Đặt mật khẩu';

  @override
  String get adminNewPassword => 'Mật khẩu mới';

  @override
  String get adminConfirmPassword => 'Nhập lại mật khẩu';

  @override
  String get adminPasswordMismatch => 'Hai mật khẩu không khớp.';

  @override
  String get adminPasswordEmptyHint =>
      'Để trống để bỏ mật khẩu. Mọi thiết bị đang đăng nhập tài khoản này sẽ bị đăng xuất.';

  @override
  String adminPasswordChanged(String name) {
    return 'Đã đổi mật khẩu cho $name.';
  }

  @override
  String adminPasswordRemoved(String name) {
    return '$name không còn mật khẩu.';
  }

  @override
  String get adminHasPassword => 'Có mật khẩu';

  @override
  String get adminNoPassword => 'Không có mật khẩu';

  @override
  String get adminDeleteUser => 'Xoá người dùng';

  @override
  String adminDeleteUserQuestion(String name) {
    return 'Xoá $name?';
  }

  @override
  String get adminDeleteUserBody =>
      'Tài khoản, danh sách phát và lịch sử xem của nó sẽ bị xoá, mọi thiết bị đang đăng nhập sẽ bị đăng xuất. Không thể hoàn tác.';

  @override
  String adminUserDeleted(String name) {
    return 'Đã xoá $name.';
  }

  @override
  String adminUserSaved(String name) {
    return 'Đã lưu thay đổi cho $name.';
  }

  @override
  String get adminUserNotFound =>
      'Máy chủ không trả về thông tin tài khoản này.';

  @override
  String get adminSectionAccount => 'Tài khoản';

  @override
  String get adminPolicyAdminBody =>
      'Có thể quản lý máy chủ và mọi tài khoản trên đó.';

  @override
  String get adminPolicyDisabledBody => 'Không đăng nhập được.';

  @override
  String get adminPolicyAdminNotDisabled =>
      'Không thể tắt tài khoản quản trị viên.';

  @override
  String get adminPolicyHidden => 'Ẩn khỏi màn hình đăng nhập';

  @override
  String get adminPolicySelf =>
      'Bạn không thể đổi mục này cho tài khoản của chính mình.';

  @override
  String get adminSectionLibraries => 'Quyền truy cập thư viện';

  @override
  String get adminPolicyAllLibraries => 'Tất cả thư viện';

  @override
  String get adminPolicyAllLibrariesBody => 'Bao gồm cả thư viện thêm sau này.';

  @override
  String get adminNoLibraries => 'Máy chủ này chưa có thư viện nào.';

  @override
  String get adminSectionPlayback => 'Phát';

  @override
  String get adminPolicyPlayback => 'Cho phép phát';

  @override
  String get adminPolicyVideoTranscoding => 'Cho phép chuyển mã video';

  @override
  String get adminPolicyAudioTranscoding => 'Cho phép chuyển mã âm thanh';

  @override
  String get adminPolicyRemuxing => 'Cho phép đóng gói lại (remux)';

  @override
  String get adminPolicyRemoteAccess => 'Cho phép truy cập từ xa';

  @override
  String get adminPolicyRemoteAccessBody => 'Từ ngoài mạng của máy chủ.';

  @override
  String get adminPolicyBitrate => 'Giới hạn bitrate từ xa';

  @override
  String get adminPolicySessions => 'Số phiên hoạt động tối đa';

  @override
  String get adminNoLimit => 'Không giới hạn';

  @override
  String adminMbps(String value) {
    return '$value Mbps';
  }

  @override
  String get adminSectionContent => 'Nội dung';

  @override
  String get adminPolicyDownloads => 'Cho phép tải xuống';

  @override
  String get adminPolicyDeletion => 'Cho phép xoá media';

  @override
  String get adminPolicyCollections => 'Cho phép quản lý bộ sưu tập';

  @override
  String get adminSectionParental => 'Kiểm soát của phụ huynh';

  @override
  String get adminPolicyMaxRating => 'Phân loại cao nhất được xem';

  @override
  String adminRatingScore(int score) {
    return 'Phân loại $score';
  }

  @override
  String get adminDiscardQuestion => 'Bỏ các thay đổi?';

  @override
  String get adminDiscardBody => 'Những gì bạn đã đổi ở đây chưa được lưu.';

  @override
  String get adminDiscard => 'Bỏ';

  @override
  String get actionSend => 'Gửi';

  @override
  String get actionRun => 'Chạy';

  @override
  String get tabSuggestions => 'Gợi ý';

  @override
  String get tabUpcoming => 'Sắp chiếu';

  @override
  String get tabGenres => 'Thể loại';

  @override
  String get noUpcoming =>
      'Chưa có tập nào trong thư viện này được lên lịch chiếu.';

  @override
  String get noGenres =>
      'Thư viện này chưa có nội dung nào được xếp theo thể loại.';

  @override
  String get upcomingUndated => 'Chưa có ngày chiếu';

  @override
  String get tabCollections => 'Bộ sưu tập';

  @override
  String get tabPlaylists => 'Danh sách phát';

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
  String itemCountAtLeast(int count) {
    return '$count+ mục';
  }

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
  String get searchMovies => 'Phim';

  @override
  String get searchShows => 'Series';

  @override
  String get searchEpisodes => 'Tập phim';

  @override
  String get searchPeople => 'Người';

  @override
  String get clearHistory => 'Xoá tất cả';

  @override
  String get removeFromHistory => 'Xoá khỏi lịch sử';

  @override
  String get whereToLook => 'Tìm ở đâu';

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
  String get autoConnectServer => 'Tự động vào máy chủ gần nhất';

  @override
  String get autoConnectServerSub =>
      'Bỏ qua danh sách máy chủ và đăng nhập vào máy chủ dùng gần đây nhất';

  @override
  String get density => 'Mật độ';

  @override
  String get playback => 'Phát lại';

  @override
  String get decoder => 'Bộ giải mã';

  @override
  String get hardwareDecodingAuto => 'Tự động (an toàn)';

  @override
  String get hardwareDecodingAutoSub =>
      'Dùng phần cứng với codec mpv tin được, còn lại dùng phần mềm';

  @override
  String get hardwareDecodingPrefer => 'Ưu tiên phần cứng';

  @override
  String get hardwareDecodingPreferSub =>
      'Mọi codec GPU nhận. Nhanh nhất, và cũng là lựa chọn dễ cho hình lỗi';

  @override
  String get hardwareDecodingSoftware => 'Chỉ phần mềm';

  @override
  String get hardwareDecodingSoftwareSub =>
      'CPU giải mã tất cả. Tốn pin hơn, nhưng phát được thứ phần cứng làm hỏng';

  @override
  String decodingNow(String decoder) {
    return 'Đang giải mã bằng: $decoder';
  }

  @override
  String get decodingSoftware => 'phần mềm';

  @override
  String get hardwareDecoding => 'Giải mã phần cứng';

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
  String updatesFromStore(String store) {
    return 'Cập nhật qua $store';
  }

  @override
  String updatesFromStoreSub(String store) {
    return 'Bản này được cài từ $store, nên $store sẽ cập nhật nó';
  }

  @override
  String get checkForUpdates => 'Kiểm tra cập nhật';

  @override
  String get autoUpdateCheck => 'Tự động kiểm tra cập nhật';

  @override
  String get autoUpdateCheckSub =>
      'Mỗi ngày một lần, từ GitHub. Không gửi thông tin nào về bạn';

  @override
  String get updateCheckEveryLaunch => 'Kiểm tra mỗi lần mở ứng dụng';

  @override
  String get updateCheckEveryLaunchSub => 'Thay vì mỗi ngày một lần';

  @override
  String get updateOfferBody => 'Đã có phiên bản mPlayer mới để cài đặt.';

  @override
  String updateOfferBodySized(String size) {
    return 'Đã có phiên bản mPlayer mới để cài đặt ($size MB).';
  }

  @override
  String get updateNow => 'Cập nhật ngay';

  @override
  String get updateLater => 'Để sau';

  @override
  String get updateSkip => 'Bỏ qua phiên bản này';

  @override
  String get updateOpenPage => 'Mở trang release';

  @override
  String get updateDownloading => 'Đang tải bản cập nhật…';

  @override
  String get updateInstalling => 'Đang cài đặt — mPlayer sẽ khởi động lại.';

  @override
  String get updateInstallerOpened =>
      'Trình cài đặt đã mở. Xác nhận ở đó để hoàn tất cập nhật.';

  @override
  String get updateNeedsPermission =>
      'Hãy cho phép mPlayer cài ứng dụng trong trang cài đặt vừa mở, rồi quay lại và thử lại.';

  @override
  String get updateNotWritable =>
      'mPlayer không ghi được vào thư mục cài đặt nên không tự cập nhật được. Hãy tải bản mới từ trang release.';

  @override
  String get updateFailed =>
      'Không cài được bản cập nhật. Bạn có thể tải từ trang release.';

  @override
  String get updateDownloadFailed =>
      'Tải chưa xong. Kiểm tra kết nối rồi thử lại, hoặc tải từ trang release.';

  @override
  String get updateTryAgain => 'Thử lại';

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
      'mPlayer không liên kết, không được bảo trợ hay tài trợ bởi dự án Jellyfin.';

  @override
  String get subtitles => 'Phụ đề';

  @override
  String get audio => 'Âm thanh';

  @override
  String get audioAndSubtitles => 'Âm thanh & phụ đề';

  @override
  String tracksValue(String audio, String subtitles) {
    return 'Âm thanh: $audio · Phụ đề: $subtitles';
  }

  @override
  String get quickBackground => 'Phát nền';

  @override
  String get quickSpeed => 'Tốc độ';

  @override
  String get quickScreenshot => 'Chụp ảnh';

  @override
  String get noTracks => 'Tệp này không có';

  @override
  String get close => 'Đóng';

  @override
  String get quality => 'Chất lượng';

  @override
  String get playbackSpeed => 'Tốc độ phát';

  @override
  String get chapters => 'Chương';

  @override
  String get previousChapter => 'Chương trước';

  @override
  String get nextChapter => 'Chương sau';

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
  String get remoteTitle => 'Điều khiển từ xa';

  @override
  String get remoteSettingsSub =>
      'Dùng điện thoại này điều khiển mPlayer trên máy tính hoặc TV';

  @override
  String get remoteSearching => 'Đang tìm mPlayer trong mạng này…';

  @override
  String get remoteNoDevices =>
      'Chưa thấy máy tính hay TV nào. Hãy mở mPlayer trên thiết bị đó và kiểm tra hai máy cùng một mạng.';

  @override
  String get remoteConnectByAddress => 'Kết nối bằng địa chỉ';

  @override
  String get remoteAddressLabel => 'Địa chỉ IP';

  @override
  String get remoteUnreachable => 'Không kết nối được tới thiết bị đó.';

  @override
  String remoteConnecting(String name) {
    return 'Đang kết nối tới $name…';
  }

  @override
  String remotePinTitle(String name) {
    return 'Ghép nối với $name';
  }

  @override
  String remotePinBody(String name) {
    return 'Nhập mã đang hiện trên $name.';
  }

  @override
  String remotePinWrong(int count) {
    return 'Sai mã. Còn $count lần thử.';
  }

  @override
  String get remotePinLabel => 'Mã';

  @override
  String get remoteDisconnect => 'Ngắt kết nối';

  @override
  String remoteNothingPlaying(String name) {
    return '$name không phát gì.';
  }

  @override
  String remoteNothingPlayingHint(String name) {
    return 'Chọn một nội dung trong thư viện rồi bấm Phát — nó sẽ phát trên $name.';
  }

  @override
  String remoteControlling(String name) {
    return 'Đang điều khiển $name';
  }

  @override
  String get remoteVolume => 'Âm lượng';

  @override
  String get remoteStop => 'Dừng';

  @override
  String get remotePrevious => 'Trước';

  @override
  String remoteSentTo(String name) {
    return 'Đang phát trên $name';
  }

  @override
  String get remotePlayHere => 'Phát ở đây';

  @override
  String remoteWrongServer(String name) {
    return '$name đang đăng nhập một server khác.';
  }

  @override
  String remoteLocked(String name) {
    return '$name đang khoá hoặc chưa đăng nhập. Hãy mở nó trên thiết bị đó trước.';
  }

  @override
  String remoteVersion(String name) {
    return '$name chạy phiên bản mPlayer khác. Hãy cập nhật cả hai.';
  }

  @override
  String remotePlayFailed(String name) {
    return 'Không phát được nội dung đó trên $name.';
  }

  @override
  String get remoteReceiverSetting => 'Cho phép điện thoại điều khiển';

  @override
  String get remoteReceiverSettingSub =>
      'mPlayer trên điện thoại cùng mạng có thể điều khiển việc phát ở đây. Điện thoại mới phải nhập mã hiện trên màn hình.';

  @override
  String get remoteForgetPhones => 'Quên các điện thoại đã ghép nối';

  @override
  String get remoteForgetPhonesSub => 'Mọi điện thoại sẽ phải nhập lại mã';

  @override
  String get remotePhonesForgotten => 'Đã quên các điện thoại đã ghép nối.';

  @override
  String remotePairingTitle(String name) {
    return '$name muốn điều khiển mPlayer';
  }

  @override
  String get remotePairingBody => 'Nhập mã này trên điện thoại';

  @override
  String remoteControlledBy(String name) {
    return 'Đang được $name điều khiển';
  }

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
  String get loop => 'Lặp';

  @override
  String get loopOne => 'Lặp lại video này';

  @override
  String get loopAll => 'Lặp lại cả thư mục';

  @override
  String qualityValue(String label) {
    return 'Chất lượng: $label';
  }

  @override
  String screenshotSaved(String folder) {
    return 'Đã lưu ảnh vào $folder';
  }

  @override
  String get screenshotFailed => 'Không chụp được khung hình này';

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
  String get privacyUpdates => 'Kiểm tra cập nhật chỉ gửi tới GitHub';

  @override
  String get privacyUpdatesBody =>
      'Khi bật \"Tự động kiểm tra cập nhật\", mPlayer hỏi API releases của GitHub mỗi ngày một lần xem có bản mới không — một yêu cầu ẩn danh, không kèm mã định danh nào. Tắt trong Cài đặt → Chung thì chỉ kiểm tra khi bạn bấm \"Kiểm tra cập nhật\". Bản cập nhật được tải từ chính trang release đó.';

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
  String get addToCollection => 'Thêm vào bộ sưu tập';

  @override
  String get newCollection => 'Bộ sưu tập mới';

  @override
  String addedToCollection(String name) {
    return 'Đã thêm vào $name';
  }

  @override
  String get selectItems => 'Chọn';

  @override
  String get selectAll => 'Chọn tất cả';

  @override
  String get clearSelection => 'Bỏ chọn';

  @override
  String selectedCount(int count) {
    return 'Đã chọn $count';
  }

  @override
  String get shuffleItems => 'Phát ngẫu nhiên';

  @override
  String get playAllFromHere => 'Phát tất cả từ đây';

  @override
  String endsAt(String time) {
    return 'Kết thúc lúc $time';
  }

  @override
  String get videoTrack => 'Video';

  @override
  String get firstAired => 'Khởi chiếu';

  @override
  String get externalLinks => 'Liên kết';

  @override
  String personBorn(String date) {
    return 'Sinh: $date';
  }

  @override
  String personDied(String date) {
    return 'Mất: $date';
  }

  @override
  String personAge(int age) {
    return '$age tuổi';
  }

  @override
  String personBirthPlace(String place) {
    return 'Nơi sinh: $place';
  }

  @override
  String get episodeLength => 'Thời lượng tập';

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
  String get addServerSub =>
      'Đăng nhập máy chủ Jellyfin để duyệt và phát thư viện của bạn.';

  @override
  String get addServerStepServer => 'Máy chủ';

  @override
  String get addServerStepAccount => 'Tài khoản';

  @override
  String get quickConnectShort => 'Quick Connect';

  @override
  String get quickConnectTitle => 'Quick Connect';

  @override
  String get quickConnectRowSub =>
      'Đăng nhập thiết bị khác bằng mã nó hiển thị';

  @override
  String get quickConnectBody =>
      'Nhập mã đang hiển thị trên thiết bị bạn muốn đăng nhập. Thiết bị đó sẽ đăng nhập bằng tài khoản của bạn.';

  @override
  String get quickConnectCode => 'Mã';

  @override
  String get quickConnectApprove => 'Duyệt';

  @override
  String get quickConnectApproved => 'Đã đăng nhập thiết bị.';

  @override
  String get quickConnectUnknownCode =>
      'Không có thiết bị nào đang chờ với mã này. Hãy kiểm tra lại hoặc lấy mã mới — mã hết hạn sau vài phút.';

  @override
  String get quickConnectRefused =>
      'Máy chủ không cho phép. Có thể Quick Connect đang bị tắt trong cài đặt máy chủ.';

  @override
  String get quickConnectSteps =>
      'Mở Cài đặt → Quick Connect trên một thiết bị đã đăng nhập và nhập mã này. Không cần gõ mật khẩu ở đây.';

  @override
  String get quickConnectOff =>
      'Máy chủ này đang tắt Quick Connect. Quản trị viên có thể bật trong bảng điều khiển.';

  @override
  String get quickConnectNewCode => 'Mã mới';

  @override
  String get quickConnectExpired =>
      'Mã đã hết hạn trước khi được duyệt. Hãy lấy mã mới và thử lại.';

  @override
  String get quickConnectRequesting => 'Đang lấy mã…';

  @override
  String quickConnectWaiting(String time) {
    return 'Đang chờ duyệt · còn $time';
  }

  @override
  String get copyCode => 'Sao chép mã';

  @override
  String get pinLockTitle => 'Khoá bằng PIN';

  @override
  String get pinLockOn => 'Bật — hỏi mỗi lần mở máy chủ này trên thiết bị';

  @override
  String get pinLockOff => 'Tắt — ai cầm thiết bị này cũng mở được máy chủ';

  @override
  String get pinEnterTitle => 'Mã PIN';

  @override
  String get pinEnterBody =>
      'Máy chủ này được khoá bằng mã PIN trên thiết bị này.';

  @override
  String get pinUnlock => 'Mở khoá';

  @override
  String get pinWrong => 'Mã PIN không đúng.';

  @override
  String pinPaused(String seconds) {
    return 'Nhập sai quá nhiều lần. Thử lại sau $seconds giây.';
  }

  @override
  String get pinSetTitle => 'Đặt mã PIN';

  @override
  String get pinSetBody =>
      'Từ 4 đến 8 chữ số. Mã được hỏi mỗi lần mở máy chủ này trên thiết bị và không gửi lên máy chủ.';

  @override
  String get pinNew => 'Mã PIN mới';

  @override
  String get pinConfirm => 'Nhập lại mã PIN';

  @override
  String get pinLength => 'Dùng từ 4 đến 8 chữ số.';

  @override
  String get pinMismatch => 'Hai mã PIN không khớp.';

  @override
  String get pinCurrent => 'Nhập mã PIN hiện tại';

  @override
  String get pinChange => 'Đổi mã PIN';

  @override
  String get pinRemove => 'Tắt mã PIN';

  @override
  String get pinSaved => 'Đã lưu mã PIN.';

  @override
  String get pinRemoved => 'Đã tắt mã PIN.';

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
  String get viewOptions => 'Tuỳ chọn hiển thị';

  @override
  String get groupByCollection => 'Gộp theo bộ sưu tập';

  @override
  String get groupByCollectionSub =>
      'Mỗi bộ sưu tập một poster thay vì từng phim trong đó. Không áp dụng khi đang lọc';

  @override
  String get startTab => 'Tab khi mở app';

  @override
  String get rememberLastTab => 'Nhớ tab cuối cùng';

  @override
  String get rememberLastTabSub => 'Mở lại tab đang dùng khi đóng app';

  @override
  String get showOnCards => 'Hiện trên thẻ';

  @override
  String get cardYear => 'Năm';

  @override
  String get cardCount => 'Số lượng';

  @override
  String get cardCountSub => 'Số tập của series, số phim của bộ sưu tập';

  @override
  String get cardStatus => 'Trạng thái';

  @override
  String get cardStatusSub => 'Series còn đang chiếu hay đã kết thúc';

  @override
  String episodeCountShort(int count) {
    return '$count tập';
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
  String get noResults => 'Không có kết quả nào';

  @override
  String get clearAll => 'Xoá hết';

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

  @override
  String get sortAndFilter => 'Sắp xếp & lọc';

  @override
  String get sortBy => 'Sắp xếp theo';

  @override
  String get sortAscending => 'Tăng dần';

  @override
  String get sortDescending => 'Giảm dần';

  @override
  String get sortCommunityRating => 'Điểm cộng đồng';

  @override
  String get sortEpisodeAdded => 'Tập mới thêm gần nhất';

  @override
  String get sortParentalRating => 'Phân loại độ tuổi';

  @override
  String get filterStatus => 'Trạng thái';

  @override
  String get filterFeatures => 'Nội dung kèm theo';

  @override
  String get filterGenres => 'Thể loại';

  @override
  String get filterParentalRatings => 'Phân loại độ tuổi';

  @override
  String get filterTags => 'Thẻ';

  @override
  String get filterYears => 'Năm';

  @override
  String get filterPlayed => 'Đã xem';

  @override
  String get filterUnplayed => 'Chưa xem';

  @override
  String get filterFavourite => 'Yêu thích';

  @override
  String get filterInProgress => 'Đang xem dở';

  @override
  String get featureTrailer => 'Trailer';

  @override
  String get featureExtras => 'Nội dung thêm';

  @override
  String get featureThemeSong => 'Nhạc chủ đề';

  @override
  String get featureThemeVideo => 'Video chủ đề';

  @override
  String get filterApply => 'Áp dụng';

  @override
  String get filterReset => 'Đặt lại';

  @override
  String get nothingToFilterBy => 'Thư viện này không còn gì khác để lọc.';

  @override
  String get heroResume => 'Xem tiếp';

  @override
  String get heroDetails => 'Chi tiết';

  @override
  String get downloadsEmptyHint =>
      'Tải một phim hoặc một tập từ trang của nó để xem ở đây khi không có mạng.';

  @override
  String get addedToDownloads => 'Đã thêm vào mục tải xuống';

  @override
  String get downloadQueued => 'Đang chờ';

  @override
  String downloadingPercent(int percent) {
    return 'Đang tải · $percent%';
  }

  @override
  String get downloadPaused => 'Đã tạm dừng';

  @override
  String get resumeDownload => 'Tiếp tục tải';

  @override
  String get retryDownload => 'Thử lại';

  @override
  String get removeDownload => 'Xoá bản tải';

  @override
  String get removeDownloadTitle => 'Xoá bản tải này?';

  @override
  String removeDownloadBody(String title) {
    return '$title sẽ không xem ngoại tuyến được nữa.';
  }

  @override
  String downloadAllTitle(int count) {
    return 'Tải $count tập?';
  }

  @override
  String get downloadAllBody =>
      'Các tập được lưu lần lượt, ở chất lượng gốc, và có thể chiếm nhiều dung lượng.';

  @override
  String get allDownloaded => 'Đã tải hết mọi tập';

  @override
  String get downloadsInProgress => 'Đang tải';

  @override
  String get downloadsCompleted => 'Đã tải';

  @override
  String get downloadsMovies => 'Phim';

  @override
  String downloadSizeOf(String received, String total) {
    return '$received / $total';
  }

  @override
  String get downloadWaitingForServer => 'Đang chờ đăng nhập server';

  @override
  String downloadsUsed(String size) {
    return '$size trên thiết bị';
  }

  @override
  String get watchDownloads => 'Xem bản đã tải';

  @override
  String downloadsQueuedMore(int count) {
    return 'còn $count mục đang chờ';
  }

  @override
  String get downloadWaitingForWifi => 'Đang chờ Wi-Fi';

  @override
  String get downloadWaitingForNetwork => 'Đang chờ kết nối mạng';

  @override
  String get downloadSettings => 'Tải xuống';

  @override
  String get downloadSettingsSub => 'Chỉ qua Wi-Fi, dung lượng';

  @override
  String get downloadWifiOnly => 'Chỉ tải qua Wi-Fi';

  @override
  String get downloadWifiOnlySub =>
      'Tạm dừng hàng đợi khi dùng dữ liệu di động và tải tiếp khi có Wi-Fi';

  @override
  String get downloadRemoveWatched => 'Xoá bản tải đã xem';

  @override
  String get downloadRemoveWatchedSub =>
      'Xoá bản tải khi đã xem hết trên thiết bị này';

  @override
  String get downloadStorage => 'Dung lượng';

  @override
  String get downloadRemoveAll => 'Xoá mọi bản tải';

  @override
  String get downloadRemoveAllTitle => 'Xoá mọi bản tải?';

  @override
  String get downloadRemoveAllBody =>
      'Mọi thứ đã lưu để xem ngoại tuyến trên thiết bị này sẽ bị xoá.';

  @override
  String get downloadsNone => 'Chưa tải gì trên thiết bị này.';

  @override
  String get tabAlbums => 'Album';

  @override
  String get tabArtists => 'Nghệ sĩ';

  @override
  String get tabSongs => 'Bài hát';

  @override
  String get noAlbums => 'Không có album nào.';

  @override
  String get noArtists => 'Không có nghệ sĩ nào.';

  @override
  String get noSongs => 'Không có bài hát nào.';

  @override
  String get musicLoadFailed => 'Không tải được từ máy chủ.';

  @override
  String get sortArtist => 'Nghệ sĩ';

  @override
  String discNumber(int number) {
    return 'Đĩa $number';
  }

  @override
  String trackCount(int count) {
    return '$count bài hát';
  }

  @override
  String get popularTracks => 'Nghe nhiều';

  @override
  String get seeAllTracks => 'Xem tất cả';

  @override
  String get appearsOn => 'Có góp mặt trong';

  @override
  String get similarArtists => 'Nghệ sĩ tương tự';

  @override
  String get nowPlaying => 'Đang phát';

  @override
  String get queue => 'Hàng đợi';

  @override
  String get queueEmpty => 'Không có gì khác trong hàng đợi.';

  @override
  String get shuffle => 'Trộn bài';

  @override
  String get stopPlayback => 'Dừng';

  @override
  String get repeatOff => 'Đang tắt lặp lại';

  @override
  String get repeatOne => 'Đang lặp lại bài này';

  @override
  String get repeatAll => 'Đang lặp lại hàng đợi';

  @override
  String get playNextInQueue => 'Phát tiếp theo';

  @override
  String get addToQueue => 'Thêm vào hàng đợi';

  @override
  String get addedToQueue => 'Đã thêm vào hàng đợi';

  @override
  String get removeFromQueue => 'Xoá khỏi hàng đợi';

  @override
  String get instantMix => 'Mix tức thì';

  @override
  String get noInstantMix => 'Máy chủ không có mix cho mục này.';

  @override
  String get recentlyPlayed => 'Nghe gần đây';
}
