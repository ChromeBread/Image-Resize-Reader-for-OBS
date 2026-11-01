--[[
================================================================================
 Image Resize Reader  -  OBS Studio Lua script (Windows)

 Fits images and videos to the canvas the moment they are added (drag & drop,
 paste, Sources +), and places them at a chosen spot. A browser dock with
 nine-point buttons moves the selected item to the edge
 of the canvas, or sets the position used for the next load.

 Author : ChromeBread feat. BlackDream
================================================================================
]]

local obs = obslua
local ffi = require("ffi")
local bit = require("bit")

--------------------------------------------------------------------------------
-- Meta
--------------------------------------------------------------------------------
local SCRIPT_NAME = "Image Resize Reader"
local GAME_ID     = "irr_game_image"
local VERSION     = "1.1.0"
local BUILD_DATE  = { year = 2026, month = 11, day = 1 }
local AUTHOR      = "ChromeBread feat. BlackDream"
local DOCK_HTML   = "obs_image_resize_reader_dock.html"
local STATE_JS    = "obs_image_resize_reader_state.js"
local PREFS_FILE  = "obs_image_resize_reader_prefs.json"
local POLL_MS     = 300
local PENDING_MAX = 300 -- seconds an item may stay empty (file dialog open) and still be fitted
local MAX_FILE    = 512 * 1024 * 1024
local MAX_DIM     = 16384

local POSITIONS = { "tl", "tc", "tr", "ml", "mc", "mr", "bl", "bc", "br" }
local ANCHOR = {
	tl = { 0, 0 },   tc = { 0.5, 0 },   tr = { 1, 0 },
	ml = { 0, 0.5 }, mc = { 0.5, 0.5 }, mr = { 1, 0.5 },
	bl = { 0, 1 },   bc = { 0.5, 1 },   br = { 1, 1 },
}

-- source type -> settings key holding the file path
local TARGET_TYPES = { image_source = "file", ffmpeg_source = "local_file", [GAME_ID] = "file" }
local TARGET_EXTS = {}
for e in ([[bmp tga png jpeg jpg jxr gif psd webp
	mp4 m4v mov mkv webm avi flv ts m2ts mts mpg mpeg wmv
	tim tm2 tim2 txd]]):gmatch("%S+") do TARGET_EXTS[e] = true end

--------------------------------------------------------------------------------
-- Localization
--------------------------------------------------------------------------------
local LANGS = { "en", "ja", "ko", "id", "fr", "zh_TW" }
local LANG_NAMES = {
	en = "English", ja = "日本語", ko = "한국어",
	id = "Bahasa Indonesia", fr = "Français", zh_TW = "繁體中文",
}

local I18N = {
	en = {
		ws_host = "WebSocket host", ws_port = "WebSocket port", ws_password = "WebSocket password",
		dock_show = "Show Dock URL", dock_hide = "Hide Dock URL",
		uninstall_info = "<b>Uninstall</b><br>1. Export your settings below if you want to keep them.<br>2. Tools → Scripts: select this script and press −.<br>3. Run Safe_Uninstaller.bat from the folder below. To remove files by hand, delete only these and leave the folder itself:<br><br>%s<br>%s",
		backup_export_file = "Export settings to", backup_export = "Export settings",
		backup_import_file = "Import settings from", backup_import = "Import settings",
		backup_no_file = "Choose a file first.", backup_failed = "The file could not be read or written.",
		backup_wrong_app = "This file belongs to a different script.",
		backup_exported = "Settings exported.", backup_imported = "Settings imported. Hotkeys apply after restarting OBS.",
		source_name = "Game Image",
		desc        = "<p>Fits images and videos to the canvas as soon as they are added, then places them at the position you chose. The dock's nine buttons move the selected item to the edge of the canvas.</p>",
		version = "Version", build_date = "Build date", author = "Author",
		language = "Language", lang_auto = "Auto (OBS)",
		lang_note = "Reload the script (⟳) to apply the language to the description and the source name.",
		debug_on = "Debug Mode: ON", debug_off = "Debug Mode: OFF",
		dock_url = "Dock URL",
		dock_howto = "1. Copy the Dock URL.\n2. In OBS: Docks → Custom Browser Docks… → enter a name and paste the URL.\n3. The dock talks to OBS via WebSocket (Tools → WebSocket Server Settings). Enter the same port / password below.",
		auto_fit = "Fit automatically on load",
		size_mode = "Size", mode_percent = "Percent of canvas", mode_pixels = "Pixel size", mode_original = "Original size",
		fit_axis = "Fit to", axis_both = "Width and height (stay inside)", axis_width = "Width", axis_height = "Height",
		percent = "Percent", px_w = "Width (px)", px_h = "Height (px)",
		upscale = "Enlarge small images to this size",
		load_pos = "Position on load",
		hk_move = "Move to: %s", hk_load = "Position on load: %s",
		tl = "Top left", tc = "Top", tr = "Top right", ml = "Left", mc = "Center", mr = "Right", bl = "Bottom left", bc = "Bottom", br = "Bottom right",
		file = "File", file_filter = "Game images", texture = "Texture", err_load = "⚠ This file could not be read: %s",
	},
	ja = {
		ws_host = "WebSocket ホスト", ws_port = "WebSocket ポート", ws_password = "WebSocket パスワード",
		dock_show = "ドックURLを表示", dock_hide = "ドックURLを隠す",
		uninstall_info = "<b>アンインストール</b><br>1. 設定を残す場合は、下の項目で書き出します。<br>2. ツール → スクリプト でこのスクリプトを選び、− を押します。<br>3. 下のフォルダにある Safe_Uninstaller.bat を実行します。手動で消す場合は次のファイルだけを削除し、フォルダ自体は消さないでください。<br><br>%s<br>%s",
		backup_export_file = "設定の書き出し先", backup_export = "設定を書き出す",
		backup_import_file = "設定の読み込み元", backup_import = "設定を読み込む",
		backup_no_file = "先にファイルを選んでください。", backup_failed = "ファイルを読み書きできませんでした。",
		backup_wrong_app = "別のスクリプトのファイルです。",
		backup_exported = "設定を書き出しました。", backup_imported = "設定を読み込みました。ホットキーはOBSの再起動後に反映されます。",
		source_name = "ゲーム画像",
		desc        = "<p>画像や動画を追加した瞬間にキャンバスへ収まる大きさへ調整し、指定した位置に配置します。ドックの9個のボタンを押すと、選択中のアイテムをキャンバスの端まで移動します。</p>",
		version = "バージョン", build_date = "ビルド日", author = "製作者",
		language = "言語", lang_auto = "自動 (OBS)",
		lang_note = "説明文とソース名への言語反映は、スクリプトの再読み込み (⟳) 後に行われます。",
		debug_on = "デバッグモード: ON", debug_off = "デバッグモード: OFF",
		dock_url = "ドックURL",
		dock_howto = "1. ドックURLをコピーします。\n2. OBSの「ドック → カスタムブラウザドック…」で名前を入力し、URLを貼り付けます。\n3. ドックは WebSocket（ツール → WebSocketサーバー設定）でOBSと通信します。同じポートとパスワードを下の欄に入力します。",
		auto_fit = "読み込み時に自動で調整する",
		size_mode = "サイズ", mode_percent = "キャンバスに対する割合", mode_pixels = "ピクセル指定", mode_original = "原寸大",
		fit_axis = "合わせる方向", axis_both = "縦横（はみ出さない）", axis_width = "横", axis_height = "縦",
		percent = "割合", px_w = "幅 (px)", px_h = "高さ (px)",
		upscale = "小さい画像もこのサイズまで拡大する",
		load_pos = "読み込み時の位置",
		hk_move = "移動: %s", hk_load = "読み込み時の位置: %s",
		tl = "左上", tc = "上", tr = "右上", ml = "左", mc = "中央", mr = "右", bl = "左下", bc = "下", br = "右下",
		file = "ファイル", file_filter = "ゲーム画像", texture = "テクスチャ", err_load = "⚠ このファイルは読み込めません: %s",
	},
	ko = {
		ws_host = "WebSocket 호스트", ws_port = "WebSocket 포트", ws_password = "WebSocket 비밀번호",
		dock_show = "도크 URL 표시", dock_hide = "도크 URL 숨기기",
		uninstall_info = "<b>제거</b><br>1. 설정을 유지하려면 아래 항목에서 내보내세요.<br>2. 도구 → 스크립트에서 이 스크립트를 선택하고 − 를 누르세요.<br>3. 아래 폴더의 Safe_Uninstaller.bat을 실행하세요. 직접 지울 때는 다음 파일만 삭제하고 폴더 자체는 지우지 마세요.<br><br>%s<br>%s",
		backup_export_file = "설정 내보내기 위치", backup_export = "설정 내보내기",
		backup_import_file = "설정 가져오기 파일", backup_import = "설정 가져오기",
		backup_no_file = "먼저 파일을 선택하세요.", backup_failed = "파일을 읽거나 쓸 수 없습니다.",
		backup_wrong_app = "다른 스크립트의 파일입니다.",
		backup_exported = "설정을 내보냈습니다.", backup_imported = "설정을 가져왔습니다. 단축키는 OBS를 다시 시작하면 적용됩니다.",
		source_name = "게임 이미지",
		desc        = "<p>이미지와 동영상을 추가하는 즉시 캔버스에 맞게 조정하고 지정한 위치에 배치합니다. 도크의 버튼 9개로 선택한 항목을 캔버스 가장자리까지 이동합니다.</p>",
		version = "버전", build_date = "빌드 날짜", author = "제작자",
		language = "언어", lang_auto = "자동 (OBS)",
		lang_note = "설명과 소스 이름에 언어를 적용하려면 스크립트를 다시 불러오세요 (⟳).",
		debug_on = "디버그 모드: ON", debug_off = "디버그 모드: OFF",
		dock_url = "도크 URL",
		dock_howto = "1. 도크 URL을 복사합니다.\n2. OBS에서 도크 → 사용자 지정 브라우저 도크… 에 이름을 입력하고 URL을 붙여넣습니다.\n3. 도크는 WebSocket(도구 → WebSocket 서버 설정)으로 OBS와 통신합니다. 같은 포트와 비밀번호를 아래 칸에 입력하세요.",
		auto_fit = "불러올 때 자동으로 조정",
		size_mode = "크기", mode_percent = "캔버스 대비 비율", mode_pixels = "픽셀 지정", mode_original = "원본 크기",
		fit_axis = "맞출 방향", axis_both = "가로세로 (벗어나지 않게)", axis_width = "가로", axis_height = "세로",
		percent = "비율", px_w = "너비 (px)", px_h = "높이 (px)",
		upscale = "작은 이미지도 이 크기까지 확대",
		load_pos = "불러올 때 위치",
		hk_move = "이동: %s", hk_load = "불러올 때 위치: %s",
		tl = "왼쪽 위", tc = "위", tr = "오른쪽 위", ml = "왼쪽", mc = "가운데", mr = "오른쪽", bl = "왼쪽 아래", bc = "아래", br = "오른쪽 아래",
		file = "파일", file_filter = "게임 이미지", texture = "텍스처", err_load = "⚠ 이 파일을 읽을 수 없습니다: %s",
	},
	id = {
		ws_host = "Host WebSocket", ws_port = "Port WebSocket", ws_password = "Kata sandi WebSocket",
		dock_show = "Tampilkan URL Dock", dock_hide = "Sembunyikan URL Dock",
		uninstall_info = "<b>Hapus instalasi</b><br>1. Ekspor pengaturan di bawah jika ingin menyimpannya.<br>2. Alat → Skrip: pilih skrip ini lalu tekan −.<br>3. Jalankan Safe_Uninstaller.bat dari folder di bawah. Untuk menghapus manual, hapus hanya file berikut dan jangan hapus foldernya:<br><br>%s<br>%s",
		backup_export_file = "Ekspor pengaturan ke", backup_export = "Ekspor pengaturan",
		backup_import_file = "Impor pengaturan dari", backup_import = "Impor pengaturan",
		backup_no_file = "Pilih file terlebih dahulu.", backup_failed = "File tidak dapat dibaca atau ditulis.",
		backup_wrong_app = "File ini milik skrip lain.",
		backup_exported = "Pengaturan diekspor.", backup_imported = "Pengaturan diimpor. Hotkey berlaku setelah OBS dimulai ulang.",
		source_name = "Gambar Game",
		desc        = "<p>Menyesuaikan gambar dan video dengan kanvas saat ditambahkan, lalu menempatkannya di posisi yang dipilih. Sembilan tombol di dock memindahkan item terpilih ke tepi kanvas.</p>",
		version = "Versi", build_date = "Tanggal build", author = "Pembuat",
		language = "Bahasa", lang_auto = "Otomatis (OBS)",
		lang_note = "Muat ulang skrip (⟳) untuk menerapkan bahasa pada deskripsi dan nama sumber.",
		debug_on = "Mode Debug: ON", debug_off = "Mode Debug: OFF",
		dock_url = "URL Dock",
		dock_howto = "1. Salin URL Dock.\n2. Di OBS: Dock → Dock Peramban Kustom… → masukkan nama dan tempel URL.\n3. Dock berkomunikasi dengan OBS melalui WebSocket (Alat → Pengaturan Server WebSocket). Masukkan port / kata sandi yang sama di bawah.",
		auto_fit = "Sesuaikan otomatis saat dimuat",
		size_mode = "Ukuran", mode_percent = "Persen dari kanvas", mode_pixels = "Ukuran piksel", mode_original = "Ukuran asli",
		fit_axis = "Sesuaikan ke", axis_both = "Lebar dan tinggi (tetap di dalam)", axis_width = "Lebar", axis_height = "Tinggi",
		percent = "Persen", px_w = "Lebar (px)", px_h = "Tinggi (px)",
		upscale = "Perbesar gambar kecil ke ukuran ini",
		load_pos = "Posisi saat dimuat",
		hk_move = "Pindah ke: %s", hk_load = "Posisi saat dimuat: %s",
		tl = "Kiri atas", tc = "Atas", tr = "Kanan atas", ml = "Kiri", mc = "Tengah", mr = "Kanan", bl = "Kiri bawah", bc = "Bawah", br = "Kanan bawah",
		file = "File", file_filter = "Gambar game", texture = "Tekstur", err_load = "⚠ File ini tidak dapat dibaca: %s",
	},
	fr = {
		ws_host = "Hôte WebSocket", ws_port = "Port WebSocket", ws_password = "Mot de passe WebSocket",
		dock_show = "Afficher l'URL du dock", dock_hide = "Masquer l'URL du dock",
		uninstall_info = "<b>Désinstallation</b><br>1. Exportez vos réglages ci-dessous si vous voulez les garder.<br>2. Outils → Scripts : sélectionnez ce script et cliquez sur −.<br>3. Lancez Safe_Uninstaller.bat depuis le dossier ci-dessous. Pour supprimer à la main, effacez uniquement ces fichiers, sans toucher au dossier :<br><br>%s<br>%s",
		backup_export_file = "Exporter les réglages vers", backup_export = "Exporter les réglages",
		backup_import_file = "Importer les réglages depuis", backup_import = "Importer les réglages",
		backup_no_file = "Choisissez d'abord un fichier.", backup_failed = "Impossible de lire ou d'écrire le fichier.",
		backup_wrong_app = "Ce fichier appartient à un autre script.",
		backup_exported = "Réglages exportés.", backup_imported = "Réglages importés. Les raccourcis s'appliquent après le redémarrage d'OBS.",
		source_name = "Image de jeu",
		desc        = "<p>Ajuste les images et vidéos au canevas dès leur ajout, puis les place à la position choisie. Les neuf boutons du dock déplacent l'élément sélectionné jusqu'au bord du canevas.</p>",
		version = "Version", build_date = "Date de build", author = "Auteur",
		language = "Langue", lang_auto = "Automatique (OBS)",
		lang_note = "Rechargez le script (⟳) pour appliquer la langue à la description et au nom de la source.",
		debug_on = "Mode débogage : ON", debug_off = "Mode débogage : OFF",
		dock_url = "URL du dock",
		dock_howto = "1. Copiez l'URL du dock.\n2. Dans OBS : Docks → Docks de navigateur personnalisés… → saisissez un nom et collez l'URL.\n3. Le dock communique avec OBS via WebSocket (Outils → Paramètres du serveur WebSocket). Saisissez le même port / mot de passe ci-dessous.",
		auto_fit = "Ajuster automatiquement au chargement",
		size_mode = "Taille", mode_percent = "Pourcentage du canevas", mode_pixels = "Taille en pixels", mode_original = "Taille d'origine",
		fit_axis = "Ajuster à", axis_both = "Largeur et hauteur (sans dépasser)", axis_width = "Largeur", axis_height = "Hauteur",
		percent = "Pourcentage", px_w = "Largeur (px)", px_h = "Hauteur (px)",
		upscale = "Agrandir les petites images à cette taille",
		load_pos = "Position au chargement",
		hk_move = "Déplacer : %s", hk_load = "Position au chargement : %s",
		tl = "En haut à gauche", tc = "En haut", tr = "En haut à droite", ml = "À gauche", mc = "Centre", mr = "À droite", bl = "En bas à gauche", bc = "En bas", br = "En bas à droite",
		file = "Fichier", file_filter = "Images de jeu", texture = "Texture", err_load = "⚠ Impossible de lire ce fichier : %s",
	},
	zh_TW = {
		ws_host = "WebSocket 主機", ws_port = "WebSocket 連接埠", ws_password = "WebSocket 密碼",
		dock_show = "顯示 Dock 網址", dock_hide = "隱藏 Dock 網址",
		uninstall_info = "<b>解除安裝</b><br>1. 若要保留設定，請先在下方匯出。<br>2. 在 工具 → 腳本 中選取此腳本並按 −。<br>3. 執行下方資料夾中的 Safe_Uninstaller.bat。若要手動刪除，請只刪除下列檔案，不要刪除資料夾本身。<br><br>%s<br>%s",
		backup_export_file = "設定匯出至", backup_export = "匯出設定",
		backup_import_file = "設定匯入來源", backup_import = "匯入設定",
		backup_no_file = "請先選擇檔案。", backup_failed = "無法讀取或寫入檔案。",
		backup_wrong_app = "此檔案屬於其他腳本。",
		backup_exported = "已匯出設定。", backup_imported = "已匯入設定。快速鍵會在重新啟動 OBS 後套用。",
		source_name = "遊戲圖片",
		desc        = "<p>在加入圖片或影片的當下自動調整為符合畫布的大小，並放到指定位置。Dock 的 9 個按鈕可將選取的項目移到畫布邊緣。</p>",
		version = "版本", build_date = "建置日期", author = "製作者",
		language = "語言", lang_auto = "自動 (OBS)",
		lang_note = "重新載入腳本 (⟳) 後，說明文字與來源名稱才會套用新語言。",
		debug_on = "偵錯模式：ON", debug_off = "偵錯模式：OFF",
		dock_url = "Dock 網址",
		dock_howto = "1. 複製 Dock 網址。\n2. 在 OBS 中：停駐視窗 → 自訂瀏覽器停駐視窗… → 輸入名稱並貼上網址。\n3. Dock 透過 WebSocket（工具 → WebSocket 伺服器設定）與 OBS 通訊，請在下方輸入相同的連接埠與密碼。",
		auto_fit = "載入時自動調整",
		size_mode = "大小", mode_percent = "畫布比例", mode_pixels = "指定像素", mode_original = "原始大小",
		fit_axis = "對齊方向", axis_both = "寬高（不超出）", axis_width = "寬", axis_height = "高",
		percent = "比例", px_w = "寬 (px)", px_h = "高 (px)",
		upscale = "將小圖放大至此大小",
		load_pos = "載入時的位置",
		hk_move = "移動: %s", hk_load = "載入時的位置: %s",
		tl = "左上", tc = "上", tr = "右上", ml = "左", mc = "中央", mr = "右", bl = "左下", bc = "下", br = "右下",
		file = "檔案", file_filter = "遊戲圖片", texture = "材質", err_load = "⚠ 無法讀取此檔案: %s",
	},
}

local MONTHS = {
	en = { "January", "February", "March", "April", "May", "June", "July",
	       "August", "September", "October", "November", "December" },
	fr = { "janvier", "février", "mars", "avril", "mai", "juin", "juillet",
	       "août", "septembre", "octobre", "novembre", "décembre" },
	id = { "Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli",
	       "Agustus", "September", "Oktober", "November", "Desember" },
}

local function format_date(d, lang)
	if lang == "ja" or lang == "zh_TW" then
		return string.format("%d年%d月%d日", d.year, d.month, d.day)
	elseif lang == "ko" then
		return string.format("%d년 %d월 %d일", d.year, d.month, d.day)
	elseif lang == "fr" then
		return (d.day == 1 and "1er" or tostring(d.day)) .. " " .. MONTHS.fr[d.month] .. " " .. d.year
	elseif lang == "id" then
		return d.day .. " " .. MONTHS.id[d.month] .. " " .. d.year
	end
	return MONTHS.en[d.month] .. " " .. d.day .. ", " .. d.year
end

-- Any OBS locale outside the six supported languages falls back to English.
local function map_locale(loc)
	loc = (loc or ""):gsub("_", "-"):lower()
	if loc:find("^ja") then return "ja" end
	if loc:find("^ko") then return "ko" end
	if loc:find("^id") then return "id" end
	if loc:find("^fr") then return "fr" end
	if loc == "zh-tw" or loc == "zh-hk" or loc:find("^zh%-hant") then return "zh_TW" end
	return "en"
end

local function detect_obs_lang()
	local ok, loc = pcall(function() return obs.obs_get_locale() end)
	return map_locale(ok and loc or "en")
end

local lang_setting = "auto" -- "auto" or one of LANGS
local current_lang = "en"

local function T(key)
	local t = I18N[current_lang] or I18N.en
	return t[key] or I18N.en[key] or key
end

local function resolve_lang()
	current_lang = (lang_setting ~= "auto" and I18N[lang_setting]) and lang_setting or detect_obs_lang()
end

--------------------------------------------------------------------------------
-- Win32 / libobs FFI
--------------------------------------------------------------------------------
ffi.cdef [[
typedef void *HANDLE;
typedef int BOOL;
typedef uint32_t DWORD;
typedef uint32_t UINT;
typedef uint16_t WCHAR;

int     MultiByteToWideChar(UINT, DWORD, const char *, int, WCHAR *, int);
HANDLE  CreateFileW(const WCHAR *, DWORD, DWORD, void *, DWORD, DWORD, HANDLE);
BOOL    ReadFile(HANDLE, void *, DWORD, DWORD *, void *);
DWORD   GetFileSize(HANDLE, DWORD *);
BOOL    CloseHandle(HANDLE);

typedef struct gs_texture gs_texture_t;
typedef struct gs_effect gs_effect_t;
typedef struct gs_effect_param gs_eparam_t;
gs_texture_t *gs_texture_create(uint32_t, uint32_t, int, uint32_t, const uint8_t **, uint32_t);
void          gs_texture_destroy(gs_texture_t *);
gs_effect_t  *obs_get_base_effect(int);
gs_eparam_t  *gs_effect_get_param_by_name(const gs_effect_t *, const char *);
void          gs_effect_set_texture(gs_eparam_t *, gs_texture_t *);
bool          gs_effect_loop(gs_effect_t *, const char *);
void          gs_draw_sprite(gs_texture_t *, uint32_t, uint32_t, uint32_t);
void          obs_enter_graphics(void);
void          obs_leave_graphics(void);
]]

local C = ffi.C
local libobs = ffi.load("obs")

local GS_BGRA            = obs.GS_BGRA or 5
local OBS_EFFECT_DEFAULT = obs.OBS_EFFECT_DEFAULT or 0
local CP_UTF8 = 65001

local function wpath(path)
	local s = path:gsub("/", "\\")
	local n = C.MultiByteToWideChar(CP_UTF8, 0, s, #s, nil, 0)
	local buf = ffi.new("WCHAR[?]", n + 1)
	if n > 0 then C.MultiByteToWideChar(CP_UTF8, 0, s, #s, buf, n) end
	buf[n] = 0
	return buf
end

-- Returns a byte buffer and its size, or nil.
local function read_binary(path)
	local h = C.CreateFileW(wpath(path), 0x80000000 --[[GENERIC_READ]], 3 --[[SHARE_READ|WRITE]],
		nil, 3 --[[OPEN_EXISTING]], 0x80, nil)
	if ffi.cast("intptr_t", h) == -1 then return nil end
	local size = C.GetFileSize(h, nil)
	if size == 0xFFFFFFFF or size == 0 or size > MAX_FILE then C.CloseHandle(h); return nil end
	local buf = ffi.new("uint8_t[?]", size)
	local got = ffi.new("DWORD[1]")
	local ok = C.ReadFile(h, buf, size, got, nil) ~= 0
	C.CloseHandle(h)
	if not ok then return nil end
	return buf, got[0]
end

local function log(level, msg)
	obs.script_log(level, msg)
end

debug_mode = false

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------
-- cfg: mode ("percent"/"pixels"/"original"), axis ("both"/"width"/"height"),
-- percent, px_w, px_h, upscale
local function compute_scale(sw, sh, cw, ch, cfg)
	if cfg.mode == "original" then return 1 end
	local tw, th = cfg.px_w, cfg.px_h
	if cfg.mode == "percent" then tw, th = cw * cfg.percent / 100, ch * cfg.percent / 100 end
	local s
	if cfg.axis == "width" then s = tw / sw
	elseif cfg.axis == "height" then s = th / sh
	else s = math.min(tw / sw, th / sh) end
	if s > 1 and not cfg.upscale then return 1 end
	return s
end

-- Top-left of a w*h box at anchor key; a box larger than the canvas is centered on that axis.
local function anchor_pos(w, h, cw, ch, key)
	local a = ANCHOR[key] or ANCHOR.mc
	local fx = w > cw and 0.5 or a[1]
	local fy = h > ch and 0.5 or a[2]
	return (cw - w) * fx, (ch - h) * fy
end

do -- self-check
	local c = { mode = "percent", axis = "both", percent = 90, px_w = 0, px_h = 0, upscale = false }
	assert(compute_scale(3840, 2160, 1920, 1080, c) == 0.45, "fit check failed")
	assert(compute_scale(100, 100, 1920, 1080, c) == 1, "no-upscale check failed")
	c.upscale = true
	assert(compute_scale(100, 100, 1920, 1080, c) == 9.72, "upscale check failed")
	local x, y = anchor_pos(100, 2000, 1920, 1080, "br")
	assert(x == 1820 and y == -460, "anchor check failed")
end

--------------------------------------------------------------------------------
-- Game image decoders: each returns width, height, BGRA buffer (non-premultiplied)
--------------------------------------------------------------------------------
local band, rshift, lshift = bit.band, bit.rshift, bit.lshift

local function need(n, off, len)
	if off < 0 or len < 0 or off + len > n then error("truncated file", 0) end
end

local function u16(b, n, o) need(n, o, 2); return b[o] + b[o + 1] * 256 end
local function u32(b, n, o) need(n, o, 4); return b[o] + b[o + 1] * 256 + b[o + 2] * 65536 + b[o + 3] * 16777216 end

local function new_image(w, h)
	if w < 1 or h < 1 or w > MAX_DIM or h > MAX_DIM then error("bad image size", 0) end
	return ffi.new("uint8_t[?]", w * h * 4)
end

local function px5(v) return math.floor(band(v, 31) * 255 / 31 + 0.5) end

-- 16-bit A1B5G5R5: all-zero means transparent, whatever the STP bit says elsewhere.
local function put_ps1555(out, i, v)
	out[i], out[i + 1], out[i + 2] = px5(rshift(v, 10)), px5(rshift(v, 5)), px5(v)
	out[i + 3] = v == 0 and 0 or 255
end

local function decode_tim(b, n)
	local flags = u32(b, n, 4)
	local pmode = band(flags, 7)
	if pmode > 3 then error("unsupported TIM mode", 0) end
	local o, clut, clut_n = 8, nil, 0
	if band(flags, 8) ~= 0 then
		local len = u32(b, n, o)
		clut_n = u16(b, n, o + 8) -- first palette row only
		need(n, o + 12, clut_n * 2)
		clut = o + 12
		o = o + len
	end
	local fw, h = u16(b, n, o + 8), u16(b, n, o + 10)
	local data, stride = o + 12, fw * 2
	local w = pmode == 0 and fw * 4 or pmode == 1 and fw * 2 or pmode == 2 and fw or math.floor(fw * 2 / 3)
	need(n, data, stride * h)
	if pmode < 2 and not clut then error("missing palette", 0) end
	local out = new_image(w, h)
	for y = 0, h - 1 do
		local row = data + y * stride
		for x = 0, w - 1 do
			local i = (y * w + x) * 4
			if pmode == 3 then
				local p = row + x * 3
				out[i], out[i + 1], out[i + 2], out[i + 3] = b[p + 2], b[p + 1], b[p], 255
			elseif pmode == 2 then
				put_ps1555(out, i, b[row + x * 2] + b[row + x * 2 + 1] * 256)
			else
				local idx
				if pmode == 1 then idx = b[row + x]
				else
					idx = b[row + rshift(x, 1)]
					idx = band(x, 1) == 0 and band(idx, 15) or rshift(idx, 4)
				end
				if idx < clut_n then put_ps1555(out, i, b[clut + idx * 2] + b[clut + idx * 2 + 1] * 256) end
			end
		end
	end
	return w, h, out
end

-- Copies one TIM2 color of the given type (1=16, 2=24, 3=32 bit); returns bytes consumed.
local function put_tim2(out, i, b, p, kind)
	if kind == 1 then
		put_ps1555(out, i, b[p] + b[p + 1] * 256)
		return 2
	end
	out[i], out[i + 1], out[i + 2] = b[p + 2], b[p + 1], b[p]
	if kind == 2 then
		out[i + 3] = 255
		return 3
	end
	out[i + 3] = math.min(b[p + 3] * 2, 255) -- GS alpha: 0x80 is opaque
	return 4
end

-- shortcut: only the first picture and its top mip level, add a picker if multi-picture files show up
local function decode_tim2(b, n)
	local o = b[5] == 1 and 128 or 16
	local image_size, header = u32(b, n, o + 8), u16(b, n, o + 12)
	local colors = u16(b, n, o + 14)
	need(n, o + 16, 8)
	local clut_type, image_type = b[o + 18], b[o + 19]
	local w, h = u16(b, n, o + 20), u16(b, n, o + 22)
	local data = o + header
	local clut = data + image_size
	local kind = band(clut_type, 0x1F)
	local out = new_image(w, h)

	if image_type >= 1 and image_type <= 3 then
		local bytes = image_type == 1 and 2 or image_type == 2 and 3 or 4
		need(n, data, w * h * bytes)
		for i = 0, w * h - 1 do put_tim2(out, i * 4, b, data + i * bytes, image_type) end
	elseif image_type == 4 or image_type == 5 then
		if kind < 1 or kind > 3 then error("missing palette", 0) end
		local stride = image_type == 5 and w or rshift(w + 1, 1)
		need(n, data, stride * h)
		local esize = kind == 1 and 2 or kind == 2 and 3 or 4
		need(n, clut, colors * esize)
		-- 8-bit palettes are stored with blocks 8-15 and 16-23 of each 32 swapped, unless bit 7 is set
		local swap = image_type == 5 and band(clut_type, 0x80) == 0
		for y = 0, h - 1 do
			local row = data + y * stride
			for x = 0, w - 1 do
				local idx
				if image_type == 5 then idx = b[row + x]
				else
					idx = b[row + rshift(x, 1)]
					idx = band(x, 1) == 0 and band(idx, 15) or rshift(idx, 4)
				end
				if swap then
					local m = band(idx, 0x18)
					if m == 0x08 then idx = idx + 8 elseif m == 0x10 then idx = idx - 8 end
				end
				if idx < colors then put_tim2(out, (y * w + x) * 4, b, clut + idx * esize, kind) end
			end
		end
	else
		error("unsupported TIM2 image type", 0)
	end
	return w, h, out
end

local function rgb565(v)
	return px5(rshift(v, 11)), math.floor(band(rshift(v, 5), 63) * 255 / 63 + 0.5), px5(v)
end

local function decode_dxt(b, n, data, w, h, kind)
	local bw, bh = rshift(w + 3, 2), rshift(h + 3, 2)
	local block = kind == 1 and 8 or 16
	need(n, data, bw * bh * block)
	local out = new_image(w, h)
	local cr, cg, cb, ca, al = {}, {}, {}, {}, {}
	for by = 0, bh - 1 do
		for bx = 0, bw - 1 do
			local p = data + (by * bw + bx) * block
			local cp = kind == 1 and p or p + 8
			local c0, c1 = b[cp] + b[cp + 1] * 256, b[cp + 2] + b[cp + 3] * 256
			cr[0], cg[0], cb[0] = rgb565(c0)
			cr[1], cg[1], cb[1] = rgb565(c1)
			ca[0], ca[1], ca[2], ca[3] = 255, 255, 255, 255
			if c0 > c1 or kind ~= 1 then
				cr[2], cg[2], cb[2] = (2 * cr[0] + cr[1]) / 3, (2 * cg[0] + cg[1]) / 3, (2 * cb[0] + cb[1]) / 3
				cr[3], cg[3], cb[3] = (cr[0] + 2 * cr[1]) / 3, (cg[0] + 2 * cg[1]) / 3, (cb[0] + 2 * cb[1]) / 3
			else
				cr[2], cg[2], cb[2] = (cr[0] + cr[1]) / 2, (cg[0] + cg[1]) / 2, (cb[0] + cb[1]) / 2
				cr[3], cg[3], cb[3], ca[3] = 0, 0, 0, 0
			end
			if kind == 5 then
				local a0, a1 = b[p], b[p + 1]
				al[0], al[1] = a0, a1
				if a0 > a1 then
					for i = 1, 6 do al[i + 1] = ((7 - i) * a0 + i * a1) / 7 end
				else
					for i = 1, 4 do al[i + 1] = ((5 - i) * a0 + i * a1) / 5 end
					al[6], al[7] = 0, 255
				end
			end
			for py = 0, 3 do
				local sel = b[cp + 4 + py]
				for px = 0, 3 do
					local x, y = bx * 4 + px, by * 4 + py
					if x < w and y < h then
						local c = band(rshift(sel, px * 2), 3)
						local i = (y * w + x) * 4
						out[i], out[i + 1], out[i + 2] = cb[c], cg[c], cr[c]
						local a = ca[c]
						if kind == 3 then
							local nib = b[p + py * 2 + rshift(px, 1)]
							a = band(rshift(nib, band(px, 1) * 4), 15) * 17
						elseif kind == 5 then
							-- 16 three-bit indices packed across bytes 2..7
							local bitpos = (py * 4 + px) * 3
							local bo = rshift(bitpos, 3)
							local v = b[p + 2 + bo] + (bo < 5 and b[p + 3 + bo] * 256 or 0)
							a = al[band(rshift(v, band(bitpos, 7)), 7)]
						end
						out[i + 3] = a
					end
				end
			end
		end
	end
	return out
end

local function txd_textures(b, n)
	local list, o = {}, 12
	need(n, o, 12)
	o = o + 12 + u32(b, n, o + 4) -- struct holding the count
	while o + 12 <= n do
		local t, size = u32(b, n, o), u32(b, n, o + 4)
		if t == 0x15 then
			local d = o + 24
			need(n, d, 88)
			local name = ffi.string(b + d + 8, 32):match("^[^%z]*")
			list[#list + 1] = { off = d, name = name }
		elseif t == 0x03 then
			break -- extension chunk ends the dictionary
		end
		o = o + 12 + size
	end
	return list
end

local function decode_txd_texture(b, n, d)
	local platform = u32(b, n, d)
	if platform ~= 8 and platform ~= 9 then error("unsupported platform (PC TXD only)", 0) end
	local raster, fmt = u32(b, n, d + 72), u32(b, n, d + 76)
	local w, h = u16(b, n, d + 80), u16(b, n, d + 82)
	local comp = b[d + 87]
	local o = d + 88
	local dxt = 0
	if platform == 8 then
		dxt = comp
	elseif band(comp, 8) ~= 0 then
		dxt = fmt == 0x31545844 and 1 or fmt == 0x33545844 and 3 or fmt == 0x35545844 and 5 or -1
	end
	if dxt ~= 0 and dxt ~= 1 and dxt ~= 3 and dxt ~= 5 then error("unsupported compression", 0) end
	if band(raster, 0x4000) ~= 0 then error("unsupported PAL4 texture", 0) end
	local pal
	if band(raster, 0x2000) ~= 0 then
		need(n, o, 1024)
		pal = o
		o = o + 1024
	end
	local size = u32(b, n, o)
	local data = o + 4
	need(n, data, size)
	if dxt ~= 0 then return w, h, decode_dxt(b, n, data, w, h, dxt) end

	local out = new_image(w, h)
	local pixels = w * h
	if pal then
		need(n, data, pixels)
		for i = 0, pixels - 1 do
			local p, q = pal + b[data + i] * 4, i * 4
			out[q], out[q + 1], out[q + 2], out[q + 3] = b[p + 2], b[p + 1], b[p], b[p + 3]
		end
		return w, h, out
	end
	local f = band(raster, 0x0F00)
	if f == 0x500 or f == 0x600 then
		need(n, data, pixels * 4)
		ffi.copy(out, b + data, pixels * 4)
		if f == 0x600 then for i = 0, pixels - 1 do out[i * 4 + 3] = 255 end end
	elseif f == 0x400 then
		need(n, data, pixels)
		for i = 0, pixels - 1 do
			local v, q = b[data + i], i * 4
			out[q], out[q + 1], out[q + 2], out[q + 3] = v, v, v, 255
		end
	elseif f == 0x100 or f == 0x200 or f == 0x300 or f == 0xA00 then
		need(n, data, pixels * 2)
		for i = 0, pixels - 1 do
			local v, q = b[data + i * 2] + b[data + i * 2 + 1] * 256, i * 4
			if f == 0x200 then
				local r, g, bl = rgb565(v)
				out[q], out[q + 1], out[q + 2], out[q + 3] = bl, g, r, 255
			elseif f == 0x300 then
				out[q] = band(v, 15) * 17
				out[q + 1] = band(rshift(v, 4), 15) * 17
				out[q + 2] = band(rshift(v, 8), 15) * 17
				out[q + 3] = rshift(v, 12) * 17
			else
				out[q], out[q + 1], out[q + 2] = px5(v), px5(rshift(v, 5)), px5(rshift(v, 10))
				out[q + 3] = (f == 0xA00 or v >= 0x8000) and 255 or 0
			end
		end
	else
		error("unsupported raster format", 0)
	end
	return w, h, out
end

-- Picks the decoder from the file contents, not the extension.
-- Returns width, height, pixels, texture names (TXD only).
local function decode_image(b, n, index)
	need(n, 0, 8)
	if b[0] == 0x54 and b[1] == 0x49 and b[2] == 0x4D and b[3] == 0x32 then -- "TIM2"
		return decode_tim2(b, n)
	end
	local magic = u32(b, n, 0)
	if magic == 0x10 then return decode_tim(b, n) end
	if magic == 0x16 then
		local list = txd_textures(b, n)
		if #list == 0 then error("empty TXD", 0) end
		local e = list[index + 1] or list[1]
		local w, h, px = decode_txd_texture(b, n, e.off)
		return w, h, px, list
	end
	error("unknown file format", 0)
end

do -- self-check: a 4bpp TIM, 4x1, palette { transparent, red }, pixels 0,1,1,0
	local t = { 0x10,0,0,0, 8,0,0,0,  16,0,0,0, 0,0,0,0, 2,0,1,0,  0,0, 0x1F,0,
		14,0,0,0, 0,0,0,0, 1,0,1,0,  0x10, 0x01 }
	local w, h, px = decode_image(ffi.new("uint8_t[?]", #t, t), #t, 0)
	assert(w == 4 and h == 1, "TIM size check failed")
	assert(px[3] == 0 and px[6] == 255 and px[7] == 255 and px[12 + 3] == 0, "TIM pixel check failed")
end

--------------------------------------------------------------------------------
-- Game Image source
--------------------------------------------------------------------------------
local function load_game_image(data, settings)
	data.path = obs.obs_data_get_string(settings, "file")
	data.width, data.height, data.pixels, data.names, data.error = 0, 0, nil, nil, nil
	data.dirty = true
	if data.path == "" then return end
	local b, n = read_binary(data.path)
	if not b then data.error = "read error"; return end
	local ok, w, h, px, list = pcall(decode_image, b, n, obs.obs_data_get_int(settings, "texture"))
	if not ok then
		data.error = tostring(w)
		log(obs.LOG_WARNING, "decode failed: " .. data.error) -- no path: the log may be on stream
		return
	end
	data.width, data.height, data.pixels = w, h, px
	if list then
		data.names = {}
		for i, e in ipairs(list) do data.names[i] = e.name end
	end
	if debug_mode then log(obs.LOG_INFO, string.format("[debug] game image %dx%d", w, h)) end
end

local source_def = {
	id           = GAME_ID,
	type         = obs.OBS_SOURCE_TYPE_INPUT,
	output_flags = bit.bor(obs.OBS_SOURCE_VIDEO, obs.OBS_SOURCE_CUSTOM_DRAW),
	icon_type    = obs.OBS_ICON_TYPE_IMAGE,
}

source_def.get_name = function() return T("source_name") end

source_def.create = function(settings, source)
	local data = { source = source, width = 0, height = 0, dirty = false, tex = nil }
	load_game_image(data, settings)
	return data
end

source_def.destroy = function(data)
	if data.tex ~= nil then
		libobs.obs_enter_graphics()
		libobs.gs_texture_destroy(data.tex)
		libobs.obs_leave_graphics()
		data.tex = nil
	end
end

source_def.update = function(data, settings) load_game_image(data, settings) end

source_def.get_properties = function(data)
	local props = obs.obs_properties_create()
	obs.obs_properties_add_path(props, "file", T("file"), obs.OBS_PATH_FILE,
		T("file_filter") .. " (*.tim *.tm2 *.tim2 *.txd)", nil)
	if data and data.names and #data.names > 1 then
		local p = obs.obs_properties_add_list(props, "texture", T("texture"),
			obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
		for i, name in ipairs(data.names) do obs.obs_property_list_add_int(p, name, i - 1) end
	end
	if data and data.error then
		obs.obs_properties_add_text(props, "irr_error", string.format(T("err_load"), data.error), obs.OBS_TEXT_INFO)
	end
	return props
end

source_def.get_width = function(data) return data.width end
source_def.get_height = function(data) return data.height end

source_def.video_render = function(data, _)
	if data.dirty then
		if data.tex ~= nil then
			libobs.gs_texture_destroy(data.tex)
			data.tex = nil
		end
		if data.pixels then
			local planes = ffi.new("const uint8_t *[1]", data.pixels)
			local tex = libobs.gs_texture_create(data.width, data.height, GS_BGRA, 1, planes, 0)
			if tex ~= nil then data.tex = tex end
		end
		data.pixels = nil
		data.dirty = false
	end
	if data.tex == nil then return end
	local effect = libobs.obs_get_base_effect(OBS_EFFECT_DEFAULT)
	libobs.gs_effect_set_texture(libobs.gs_effect_get_param_by_name(effect, "image"), data.tex)
	while libobs.gs_effect_loop(effect, "Draw") do
		libobs.gs_draw_sprite(data.tex, 0, data.width, data.height)
	end
end

--------------------------------------------------------------------------------
-- Scene items
--------------------------------------------------------------------------------
local script_settings = nil
local cfg = { auto_fit = true, mode = "percent", axis = "both", percent = 90,
	px_w = 1920, px_h = 1080, upscale = false, pos = "mc" }
local scenes = {}        -- scene name -> { max = highest item id seen, pending = { [id] = time } }
local seen_sources = {}  -- source names already in a scene: adding those again is not a load
local last_item = nil    -- { scene = name, id = id }, the fallback when nothing is selected
local ready = true

local function canvas_scene()
	if obs.obs_frontend_preview_program_mode_active() then
		return obs.obs_frontend_get_current_preview_scene()
	end
	return obs.obs_frontend_get_current_scene()
end

local function baseline_scene(name, scene_src)
	local st = { max = 0, pending = {} }
	local items = obs.obs_scene_enum_items(obs.obs_scene_from_source(scene_src))
	for _, it in ipairs(items or {}) do
		st.max = math.max(st.max, obs.obs_sceneitem_get_id(it))
		seen_sources[obs.obs_source_get_name(obs.obs_sceneitem_get_source(it))] = true
	end
	if items then obs.sceneitem_list_release(items) end
	scenes[name] = st
end

local function baseline_all()
	scenes, seen_sources = {}, {}
	local list = obs.obs_frontend_get_scenes()
	for _, s in ipairs(list or {}) do baseline_scene(obs.obs_source_get_name(s), s) end
	if list then obs.source_list_release(list) end
end

local function fit_item(item, scene_src, name)
	local src = obs.obs_sceneitem_get_source(item)
	local sw, sh = obs.obs_source_get_width(src), obs.obs_source_get_height(src)
	local cw, ch = obs.obs_source_get_width(scene_src), obs.obs_source_get_height(scene_src)
	local s = compute_scale(sw, sh, cw, ch, cfg)
	local x, y = anchor_pos(sw * s, sh * s, cw, ch, cfg.pos)

	obs.obs_sceneitem_set_alignment(item, 5) -- OBS_ALIGN_LEFT | OBS_ALIGN_TOP
	local v = obs.vec2()
	v.x, v.y = s, s
	obs.obs_sceneitem_set_scale(item, v)
	v.x, v.y = math.floor(x + 0.5), math.floor(y + 0.5)
	obs.obs_sceneitem_set_pos(item, v)

	last_item = { scene = name, id = obs.obs_sceneitem_get_id(item) }
	if debug_mode then
		log(obs.LOG_INFO, string.format("[debug] fit %dx%d -> scale %.3f at %d,%d (%s)", sw, sh, s, v.x, v.y, cfg.pos))
	end
end

-- OBS's drop handler treats .txd as a media file (the VCD subtitle format), so it arrives as a
-- Media Source that can't play. Swap in a Game Image source under the same name.
local function swap_txd(scene, item, src, path)
	local name = obs.obs_source_get_name(src)
	local settings = obs.obs_data_create()
	obs.obs_data_set_string(settings, "file", path)
	obs.obs_source_set_name(src, name .. " (txd)")
	local new_src = obs.obs_source_create(GAME_ID, name, settings, nil)
	obs.obs_data_release(settings)
	local new_item = new_src and obs.obs_scene_add(scene, new_src)
	if new_src then obs.obs_source_release(new_src) end
	if not new_item then
		obs.obs_source_set_name(src, name)
		return nil
	end
	obs.obs_source_remove(src)
	return obs.obs_sceneitem_get_id(new_item)
end

-- Returns "wait" while the item has no file or size yet, a new item id after a swap.
local function process_item(scene, item, scene_src, name)
	local src = obs.obs_sceneitem_get_source(item)
	local key = TARGET_TYPES[obs.obs_source_get_unversioned_id(src)]
	if not key then return end
	local settings = obs.obs_source_get_settings(src)
	local path = obs.obs_data_get_string(settings, key)
	obs.obs_data_release(settings)
	if path == "" then return "wait" end
	local ext = path:match("%.([^%.\\/]+)$")
	ext = ext and ext:lower() or ""
	if not TARGET_EXTS[ext] then return end
	if ext == "txd" and key == "local_file" then return swap_txd(scene, item, src, path) end
	if obs.obs_source_get_width(src) == 0 or obs.obs_source_get_height(src) == 0 then return "wait" end
	fit_item(item, scene_src, name)
end

local function poll()
	if not ready then return end
	local scene_src = canvas_scene()
	if not scene_src then return end
	local name = obs.obs_source_get_name(scene_src)
	local st = scenes[name]
	if not st then
		baseline_scene(name, scene_src)
		obs.obs_source_release(scene_src)
		return
	end
	local scene = obs.obs_scene_from_source(scene_src)
	local now, keep, top = os.time(), {}, st.max
	local items = obs.obs_scene_enum_items(scene)
	for _, it in ipairs(items or {}) do
		local id = obs.obs_sceneitem_get_id(it)
		if id > st.max then
			top = math.max(top, id)
			local sname = obs.obs_source_get_name(obs.obs_sceneitem_get_source(it))
			if not seen_sources[sname] and cfg.auto_fit then st.pending[id] = now end
			seen_sources[sname] = true
		end
		local since = st.pending[id]
		if since and now - since <= PENDING_MAX then
			local r = process_item(scene, it, scene_src, name)
			if r == "wait" then
				keep[id] = since
			elseif r then
				keep[r] = now -- the swapped-in source is fitted on the next poll
				top = math.max(top, r)
				seen_sources[obs.obs_source_get_name(obs.obs_sceneitem_get_source(it))] = true
			end
		end
	end
	if items then obs.sceneitem_list_release(items) end
	st.max, st.pending = top, keep
	obs.obs_source_release(scene_src)
end

-- Moves the item so its on-screen box touches the anchor. The box transform covers
-- rotation, crop and bounds, so this works on anything the user already arranged.
local function move_item(item, scene_src, key)
	local m = obs.matrix4()
	obs.obs_sceneitem_get_box_transform(item, m)
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
		local x = m.x.x * c[1] + m.y.x * c[2] + m.t.x
		local y = m.x.y * c[1] + m.y.y * c[2] + m.t.y
		x0, y0, x1, y1 = math.min(x0, x), math.min(y0, y), math.max(x1, x), math.max(y1, y)
	end
	local cw, ch = obs.obs_source_get_width(scene_src), obs.obs_source_get_height(scene_src)
	local tx, ty = anchor_pos(x1 - x0, y1 - y0, cw, ch, key)
	local v = obs.vec2()
	obs.obs_sceneitem_get_pos(item, v)
	v.x, v.y = v.x + tx - x0, v.y + ty - y0
	obs.obs_sceneitem_set_pos(item, v)
end

local function move_selection(key)
	local scene_src = canvas_scene()
	if not scene_src then return end
	local name = obs.obs_source_get_name(scene_src)
	local scene = obs.obs_scene_from_source(scene_src)
	local moved = 0
	local items = obs.obs_scene_enum_items(scene)
	for _, it in ipairs(items or {}) do
		if obs.obs_sceneitem_selected(it) then
			move_item(it, scene_src, key)
			moved = moved + 1
		end
	end
	if items then obs.sceneitem_list_release(items) end
	if moved == 0 and last_item and last_item.scene == name then
		local it = obs.obs_scene_find_sceneitem_by_id(scene, last_item.id)
		if it then
			move_item(it, scene_src, key)
			moved = 1
		end
	end
	if debug_mode then log(obs.LOG_INFO, string.format("[debug] moved %d item(s) to %s", moved, key)) end
	obs.obs_source_release(scene_src)
end

--------------------------------------------------------------------------------
-- Dock state and preferences
--------------------------------------------------------------------------------
local function script_dir()
	local ok, p = pcall(script_path)
	p = ok and p or ""
	p = p:gsub("\\", "/")
	if p ~= "" and p:sub(-1) ~= "/" then p = p .. "/" end
	return p
end

local function file_url(path)
	path = path:gsub("\\", "/")
	local enc = path:gsub("[^%w%-%._~/:]", function(c) return string.format("%%%02X", c:byte()) end)
	return "file:///" .. enc
end

-- The dock has no connection fields, so it reads these from here, like OBS's own WebSocket settings.
local ws_json = '{"host":"localhost","port":4455,"password":""}'

local function set_ws(settings)
	local function quoted(s)
		return '"' .. (s:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end)) .. '"'
	end
	local host = obs.obs_data_get_string(settings, "ws_host")
	ws_json = string.format('{"host":%s,"port":%d,"password":%s}', quoted(host ~= "" and host or "localhost"),
		obs.obs_data_get_int(settings, "ws_port"), quoted(obs.obs_data_get_string(settings, "ws_password")))
end

local function write_dock_state()
	local st = string.format(
		'irrState({"lang":"%s","pos":"%s","name":"%s","version":"%s","buildDate":"%s","author":"%s","ws":%s});',
		current_lang, cfg.pos, SCRIPT_NAME, VERSION, format_date(BUILD_DATE, current_lang), AUTHOR, ws_json)
	obs.os_quick_write_utf8_file(script_dir() .. STATE_JS, st, #st, false)
end

local function set_load_pos(key)
	cfg.pos = key
	if script_settings then obs.obs_data_set_string(script_settings, "load_pos", key) end
	write_dock_state()
end

local function load_prefs()
	local d = obs.obs_data_create_from_json_file_safe(script_dir() .. PREFS_FILE, "bak")
	if d then
		local l = obs.obs_data_get_string(d, "language")
		if l == "auto" or I18N[l] then lang_setting = l end
		obs.obs_data_release(d)
	end
end

local function save_prefs()
	local d = obs.obs_data_create()
	obs.obs_data_set_string(d, "language", lang_setting)
	obs.obs_data_save_json_safe(d, script_dir() .. PREFS_FILE, "tmp", "bak")
	obs.obs_data_release(d)
end

load_prefs()
resolve_lang()

--------------------------------------------------------------------------------
-- Script
--------------------------------------------------------------------------------
local SCRIPT_LABELS = {
	language = "language", lang_note = "lang_note", dock_url = "dock_url", dock_info = "dock_howto",
	auto_fit = "auto_fit", size_mode = "size_mode", fit_axis = "fit_axis", percent = "percent",
	px_w = "px_w", px_h = "px_h", upscale = "upscale", load_pos = "load_pos",
}

local UNINSTALL_FILES = "obs_image_resize_reader.lua<br>obs_image_resize_reader_dock.html<br>obs_image_resize_reader_prefs.json<br>obs_image_resize_reader_state.js"
local BACKUP_SKIP = { "dock_url", "ws_password", "backup_export_file", "backup_import_file" }

local DEBUG_LABELS = {
	backup_export_file = "backup_export_file", backup_export = "backup_export",
	backup_import_file = "backup_import_file", backup_import = "backup_import",
}

local dock_shown = false

local function apply_debug_props(props)
	for _, name in ipairs({ "ws_host", "ws_port", "ws_password" }) do
		obs.obs_property_set_description(obs.obs_properties_get(props, name), T(name))
	end
	for _, name in ipairs({ "dock_url", "dock_info", "ws_host", "ws_port", "ws_password" }) do
		obs.obs_property_set_visible(obs.obs_properties_get(props, name), dock_shown or debug_mode)
	end
	obs.obs_property_set_description(obs.obs_properties_get(props, "dock_toggle"), T(dock_shown and "dock_hide" or "dock_show"))
	for name, key in pairs(DEBUG_LABELS) do
		local p = obs.obs_properties_get(props, name)
		if p then
			obs.obs_property_set_description(p, T(key))
			obs.obs_property_set_visible(p, debug_mode)
		end
	end
	local info = obs.obs_properties_get(props, "uninstall_info")
	if info then
		-- The folder can reveal a user name, so this stays behind Debug Mode.
		obs.obs_property_set_description(info, string.format(T("uninstall_info"), script_dir(), UNINSTALL_FILES))
		obs.obs_property_set_visible(info, debug_mode)
	end
	local status = obs.obs_properties_get(props, "backup_status")
	if status then obs.obs_property_set_visible(status, debug_mode) end
end

local function apply_script_props(props, settings)
	for name, key in pairs(SCRIPT_LABELS) do
		local p = obs.obs_properties_get(props, name)
		if p then obs.obs_property_set_description(p, T(key)) end
	end
	obs.obs_property_set_description(obs.obs_properties_get(props, "debug_toggle"),
		debug_mode and T("debug_on") or T("debug_off"))
	local mode = obs.obs_data_get_string(settings or script_settings, "size_mode")
	obs.obs_property_set_visible(obs.obs_properties_get(props, "percent"), mode == "percent")
	obs.obs_property_set_visible(obs.obs_properties_get(props, "px_w"), mode == "pixels")
	obs.obs_property_set_visible(obs.obs_properties_get(props, "px_h"), mode == "pixels")
	obs.obs_property_set_visible(obs.obs_properties_get(props, "fit_axis"), mode ~= "original")
	obs.obs_property_set_visible(obs.obs_properties_get(props, "upscale"), mode ~= "original")
	apply_debug_props(props)
end

local function on_language_changed(props, _, settings)
	local l = obs.obs_data_get_string(settings, "language")
	if l ~= lang_setting then
		lang_setting = (l == "auto" or I18N[l]) and l or "auto"
		resolve_lang()
		save_prefs()
		write_dock_state()
	end
	apply_script_props(props, settings)
	return true
end

local function on_mode_changed(props, _, settings)
	apply_script_props(props, settings)
	return true
end

local function set_backup_status(props, text)
	obs.obs_property_set_description(obs.obs_properties_get(props, "backup_status"), text)
	log(obs.LOG_INFO, text)
end

local function backup_path(key)
	return script_settings and obs.obs_data_get_string(script_settings, key) or ""
end

-- One readable JSON file, so a setting can still be copied by hand on another PC.
local function on_backup_export(props, _)
	local path = backup_path("backup_export_file")
	if path == "" then set_backup_status(props, T("backup_no_file")); return true end
	if script_save then script_save(script_settings) end
	local data = obs.obs_data_create()
	local settings = obs.obs_data_create_from_json(obs.obs_data_get_json(script_settings))
	for _, key in ipairs(BACKUP_SKIP) do obs.obs_data_erase(settings, key) end
	obs.obs_data_set_string(data, "app", SCRIPT_NAME)
	obs.obs_data_set_string(data, "version", VERSION)
	obs.obs_data_set_obj(data, "settings", settings)
	local prefs = obs.obs_data_create_from_json_file(script_dir() .. PREFS_FILE)
	if prefs then
		obs.obs_data_set_obj(data, "prefs", prefs)
		obs.obs_data_release(prefs)
	end
	local save = obs.obs_data_save_json_pretty or obs.obs_data_save_json
	local ok = save(data, path)
	obs.obs_data_release(settings)
	obs.obs_data_release(data)
	set_backup_status(props, ok and T("backup_exported") or T("backup_failed"))
	return true
end

local function on_backup_import(props, _)
	local path = backup_path("backup_import_file")
	if path == "" then set_backup_status(props, T("backup_no_file")); return true end
	local data = obs.obs_data_create_from_json_file(path)
	if not data then set_backup_status(props, T("backup_failed")); return true end
	if obs.obs_data_get_string(data, "app") ~= SCRIPT_NAME then
		obs.obs_data_release(data)
		set_backup_status(props, T("backup_wrong_app"))
		return true
	end
	local settings = obs.obs_data_get_obj(data, "settings")
	if settings then
		for _, key in ipairs(BACKUP_SKIP) do obs.obs_data_erase(settings, key) end
		obs.obs_data_erase(settings, "debug_mode")
		obs.obs_data_apply(script_settings, settings)
		obs.obs_data_release(settings)
	end
	local prefs = obs.obs_data_get_obj(data, "prefs")
	if prefs then
		obs.obs_data_save_json_safe(prefs, script_dir() .. PREFS_FILE, "tmp", "bak")
		obs.obs_data_release(prefs)
		load_prefs()
		resolve_lang()
	end
	obs.obs_data_release(data)
	obs.obs_data_set_string(script_settings, "language", lang_setting)
	if script_update then script_update(script_settings) end
	write_dock_state()
	apply_script_props(props)
	set_backup_status(props, T("backup_imported"))
	return true
end

local function on_dock_toggle(props, _)
	dock_shown = not dock_shown
	apply_script_props(props)
	return true
end

local function add_debug_props(props)
	obs.obs_properties_add_text(props, "uninstall_info", "", obs.OBS_TEXT_INFO)
	obs.obs_properties_add_path(props, "backup_export_file", "", obs.OBS_PATH_FILE_SAVE, "JSON (*.json)", nil)
	obs.obs_properties_add_button(props, "backup_export", "", on_backup_export)
	obs.obs_properties_add_path(props, "backup_import_file", "", obs.OBS_PATH_FILE, "JSON (*.json)", nil)
	obs.obs_properties_add_button(props, "backup_import", "", on_backup_import)
	obs.obs_properties_add_text(props, "backup_status", " ", obs.OBS_TEXT_INFO)
end

local function on_debug_toggle(props, _)
	debug_mode = not debug_mode
	if script_settings then obs.obs_data_set_bool(script_settings, "debug_mode", debug_mode) end
	apply_script_props(props)
	return true
end

function script_description()
	return string.format([[<h2>%s</h2>%s<hr/>
<table>
<tr><td><b>%s</b></td><td>&nbsp;&nbsp;%s</td></tr>
<tr><td><b>%s</b></td><td>&nbsp;&nbsp;%s</td></tr>
<tr><td><b>%s</b></td><td>&nbsp;&nbsp;%s</td></tr>
</table>]],
		SCRIPT_NAME, T("desc"),
		T("version"), VERSION,
		T("build_date"), format_date(BUILD_DATE, current_lang),
		T("author"), AUTHOR)
end

function script_properties()
	local props = obs.obs_properties_create()

	local lp = obs.obs_properties_add_list(props, "language", T("language"),
		obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
	obs.obs_property_list_add_string(lp,
		T("lang_auto") .. " - " .. LANG_NAMES[detect_obs_lang()], "auto")
	for _, l in ipairs(LANGS) do obs.obs_property_list_add_string(lp, LANG_NAMES[l], l) end
	obs.obs_property_set_modified_callback(lp, on_language_changed)
	obs.obs_properties_add_text(props, "lang_note", T("lang_note"), obs.OBS_TEXT_INFO)

	obs.obs_properties_add_bool(props, "auto_fit", T("auto_fit"))
	local mp = obs.obs_properties_add_list(props, "size_mode", T("size_mode"),
		obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
	obs.obs_property_list_add_string(mp, T("mode_percent"), "percent")
	obs.obs_property_list_add_string(mp, T("mode_pixels"), "pixels")
	obs.obs_property_list_add_string(mp, T("mode_original"), "original")
	obs.obs_property_set_modified_callback(mp, on_mode_changed)
	local ap = obs.obs_properties_add_list(props, "fit_axis", T("fit_axis"),
		obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
	obs.obs_property_list_add_string(ap, T("axis_both"), "both")
	obs.obs_property_list_add_string(ap, T("axis_width"), "width")
	obs.obs_property_list_add_string(ap, T("axis_height"), "height")
	local pc = obs.obs_properties_add_int_slider(props, "percent", T("percent"), 1, 100, 1)
	obs.obs_property_int_set_suffix(pc, " %")
	obs.obs_properties_add_int(props, "px_w", T("px_w"), 1, MAX_DIM, 1)
	obs.obs_properties_add_int(props, "px_h", T("px_h"), 1, MAX_DIM, 1)
	obs.obs_properties_add_bool(props, "upscale", T("upscale"))
	local pp = obs.obs_properties_add_list(props, "load_pos", T("load_pos"),
		obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
	for _, k in ipairs(POSITIONS) do obs.obs_property_list_add_string(pp, T(k), k) end

	obs.obs_properties_add_button(props, "dock_toggle", T("dock_show"), on_dock_toggle)
	obs.obs_properties_add_text(props, "dock_url", T("dock_url"), obs.OBS_TEXT_DEFAULT)
	obs.obs_properties_add_text(props, "dock_info", T("dock_howto"), obs.OBS_TEXT_INFO)
	obs.obs_properties_add_text(props, "ws_host", T("ws_host"), obs.OBS_TEXT_DEFAULT)
	obs.obs_properties_add_int(props, "ws_port", T("ws_port"), 1, 65535, 1)
	obs.obs_properties_add_text(props, "ws_password", T("ws_password"), obs.OBS_TEXT_PASSWORD)
	obs.obs_properties_add_button(props, "debug_toggle", T("debug_off"), on_debug_toggle)

	add_debug_props(props)
	apply_script_props(props)
	return props
end

function script_defaults(settings)
	obs.obs_data_set_default_string(settings, "language", "auto")
	obs.obs_data_set_default_bool(settings, "debug_mode", false)
	obs.obs_data_set_default_string(settings, "ws_host", "localhost")
	obs.obs_data_set_default_int(settings, "ws_port", 4455)
	obs.obs_data_set_default_string(settings, "ws_password", "")
	obs.obs_data_set_default_bool(settings, "auto_fit", true)
	obs.obs_data_set_default_string(settings, "size_mode", "percent")
	obs.obs_data_set_default_string(settings, "fit_axis", "both")
	obs.obs_data_set_default_int(settings, "percent", 90)
	obs.obs_data_set_default_int(settings, "px_w", 1920)
	obs.obs_data_set_default_int(settings, "px_h", 1080)
	obs.obs_data_set_default_bool(settings, "upscale", false)
	obs.obs_data_set_default_string(settings, "load_pos", "mc")
end

function script_update(settings)
	set_ws(settings)
	write_dock_state()
	cfg.auto_fit = obs.obs_data_get_bool(settings, "auto_fit")
	cfg.mode     = obs.obs_data_get_string(settings, "size_mode")
	cfg.axis     = obs.obs_data_get_string(settings, "fit_axis")
	cfg.percent  = obs.obs_data_get_int(settings, "percent")
	cfg.px_w     = obs.obs_data_get_int(settings, "px_w")
	cfg.px_h     = obs.obs_data_get_int(settings, "px_h")
	cfg.upscale  = obs.obs_data_get_bool(settings, "upscale")
	local pos = obs.obs_data_get_string(settings, "load_pos")
	if ANCHOR[pos] and pos ~= cfg.pos then
		cfg.pos = pos
		write_dock_state()
	end
end

-- The dock calls these through obs-websocket's TriggerHotkeyByName.
local hotkeys = {}

local function register_hotkeys(settings)
	for _, k in ipairs(POSITIONS) do
		local function add(prefix, label, fn)
			local name = prefix .. k
			local id = obs.obs_hotkey_register_frontend(name,
				SCRIPT_NAME .. " - " .. string.format(T(label), T(k)),
				function(pressed) if pressed then fn(k) end end)
			local arr = obs.obs_data_get_array(settings, name)
			obs.obs_hotkey_load(id, arr)
			obs.obs_data_array_release(arr)
			hotkeys[name] = id
		end
		add("irr_move_", "hk_move", move_selection)
		add("irr_load_", "hk_load", set_load_pos)
	end
end

function script_save(settings)
	for name, id in pairs(hotkeys) do
		local arr = obs.obs_hotkey_save(id)
		obs.obs_data_set_array(settings, name, arr)
		obs.obs_data_array_release(arr)
	end
end

local function on_frontend_event(event)
	if event == obs.OBS_FRONTEND_EVENT_SCENE_COLLECTION_CHANGING then
		ready = false
	elseif event == obs.OBS_FRONTEND_EVENT_SCENE_COLLECTION_CHANGED then
		baseline_all()
		ready = true
	end
end

function script_load(settings)
	script_settings = settings
	obs.obs_data_set_string(settings, "language", lang_setting)
	obs.obs_data_set_string(settings, "dock_url", file_url(script_dir() .. DOCK_HTML))
	debug_mode = obs.obs_data_get_bool(settings, "debug_mode")
	set_ws(settings)

	obs.obs_register_source(source_def)
	register_hotkeys(settings)
	script_update(settings)
	write_dock_state()
	baseline_all()
	obs.obs_frontend_add_event_callback(on_frontend_event)
	obs.timer_add(poll, POLL_MS)
	log(obs.LOG_INFO, string.format("%s %s loaded (lang=%s, debug=%s)",
		SCRIPT_NAME, VERSION, current_lang, tostring(debug_mode)))
end

function script_unload()
	obs.timer_remove(poll)
end
