# Safe Uninstaller for the #cbOBScripts Lua scripts. The list of items comes from Safe_Uninstaller.config.json.
# It only ever touches the names in that list, only after OBS is closed, and only through the Recycle Bin.
param([string]$SelfTest)

$ErrorActionPreference = 'Stop'
$Here = $PSScriptRoot
[Environment]::CurrentDirectory = $env:TEMP # the folder this runs from may be one of the items
$Config = Get-Content -Raw -Encoding UTF8 (Join-Path $Here 'Safe_Uninstaller.config.json') | ConvertFrom-Json

# The plugin lives under ProgramData, where moving a folder needs administrator rights.
if ($Config.admin -and -not $SelfTest) {
  $identity = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
  if (-not $identity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', "`"$PSCommandPath`"")
    exit 0
  }
}

$Root = if ($Config.root) { [IO.Path]::GetFullPath((Join-Path $Here $Config.root)) } else { $Here }
$script:ConfigRoot = Join-Path $env:APPDATA 'obs-studio\plugin_config'

$Text = @{
  en = @{ Title='Safe Uninstaller'; Language='Language'; Folder='Installed folder'; Item='Item'; Kind='What it is'; Size='Size'
    core='Needed to run'; settings='Your settings (keep to reinstall)'; generated='Made automatically (not needed)'; old='Left by an old version (not needed)'
    Backup='Back up settings...'; Move='Moving to another PC'; Remove='Uninstall checked items'; Close='Close'
    ObsRunning='OBS is running. Close OBS to uninstall.'; Registered='Still listed in Tools > Scripts in: {0}. Remove it there first (select it and press -).'; Ready='Ready. Checked items go to the Recycle Bin, so you can still restore them.'
    NotFound='No installed files were found.'; Confirm='Move {0} item(s) to the Recycle Bin?'; Done='Moved {0} item(s) to the Recycle Bin.'; Failed='Could not remove: {0}'
    NoSettings='There are no settings files to back up.'; BackedUp='Saved to:{0}{1}'; BackupPick='Choose where to save the backup'
    MoveText="1. Open this script in Tools > Scripts, turn Debug Mode ON and press Export settings.`n2. Press Back up settings here as well.`n3. Copy both to the other PC.`n4. Install the script there and use Import settings.`n`nDevice names can differ between PCs. The exported .json is readable, so you can set them by hand."
    MoveTextPlugin="1. Open Tools > #cbOBScripts > VST Ex Audio Filter, turn Debug mode on, and use Backup to export.`n2. Copy the exported folder to the other PC.`n3. Install VST Ex Audio Filter and the same VST plugins there, then import the backup.`n`nDevice and plugin names can differ between PCs, and scene collections are moved separately with OBS. The backup holds readable files, so you can set things by hand." }
  ja = @{ Title='安全アンインストーラー'; Language='言語'; Folder='インストール先'; Item='項目'; Kind='内容'; Size='サイズ'
    core='動作に必要'; settings='設定 (再導入するなら残す)'; generated='自動生成 (不要)'; old='旧バージョンの残り (不要)'
    Backup='設定をバックアップ...'; Move='別のPCへのお引越し'; Remove='チェックした項目をアンインストール'; Close='閉じる'
    ObsRunning='OBSが起動中です。OBSを閉じてからアンインストールしてください。'; Registered='次のシーンコレクションの ツール > スクリプト に残っています: {0}。先に選択して - で外してください。'; Ready='準備完了。チェックした項目はごみ箱へ移動するので、あとから元に戻せます。'
    NotFound='インストール済みのファイルは見つかりませんでした。'; Confirm='{0} 件をごみ箱へ移動しますか？'; Done='{0} 件をごみ箱へ移動しました。'; Failed='移動できませんでした: {0}'
    NoSettings='バックアップする設定ファイルがありません。'; BackedUp='保存しました:{0}{1}'; BackupPick='バックアップの保存先を選んでください'
    MoveText="1. ツール > スクリプト でこのスクリプトを開き、デバッグモードをONにして「設定を書き出す」を押します。`n2. ここの「設定をバックアップ」も押します。`n3. 両方を別のPCへコピーします。`n4. 別のPCでスクリプトを導入し、「設定を読み込む」を使います。`n`nデバイス名はPCごとに異なる場合があります。書き出した .json は読める形式なので、手動でも再現できます。"
    MoveTextPlugin="1. ツール > #cbOBScripts > VST Ex Audio Filter を開き、デバッグモードをONにして、バックアップから書き出します。`n2. 書き出したフォルダを別のPCへコピーします。`n3. 別のPCに VST Ex Audio Filter と同じVSTプラグインを導入し、バックアップを読み込みます。`n`nデバイス名やプラグイン名はPCごとに異なる場合があります。シーンコレクションはOBS側で別に移します。バックアップは読める形式なので、手動でも再現できます。" }
  ko = @{ Title='안전 제거 도구'; Language='언어'; Folder='설치 폴더'; Item='항목'; Kind='내용'; Size='크기'
    core='실행에 필요'; settings='설정 (재설치 시 보관)'; generated='자동 생성 (불필요)'; old='이전 버전의 잔여물 (불필요)'
    Backup='설정 백업...'; Move='다른 PC로 옮기기'; Remove='선택한 항목 제거'; Close='닫기'
    ObsRunning='OBS가 실행 중입니다. OBS를 닫은 뒤 제거하세요.'; Registered='다음 장면 모음의 도구 > 스크립트에 남아 있습니다: {0}. 먼저 선택하고 - 를 눌러 빼세요.'; Ready='준비되었습니다. 선택한 항목은 휴지통으로 이동하므로 나중에 되돌릴 수 있습니다.'
    NotFound='설치된 파일을 찾지 못했습니다.'; Confirm='{0}개 항목을 휴지통으로 옮길까요?'; Done='{0}개 항목을 휴지통으로 옮겼습니다.'; Failed='옮기지 못했습니다: {0}'
    NoSettings='백업할 설정 파일이 없습니다.'; BackedUp='저장했습니다:{0}{1}'; BackupPick='백업 저장 위치를 선택하세요'
    MoveText="1. 도구 > 스크립트에서 이 스크립트를 열고 디버그 모드를 켠 뒤 설정 내보내기를 누르세요.`n2. 여기의 설정 백업도 누르세요.`n3. 둘 다 다른 PC로 복사하세요.`n4. 다른 PC에서 스크립트를 설치하고 설정 가져오기를 사용하세요.`n`n장치 이름은 PC마다 다를 수 있습니다. 내보낸 .json은 읽을 수 있는 형식이므로 직접 다시 설정할 수 있습니다."
    MoveTextPlugin="1. 도구 > #cbOBScripts > VST Ex Audio Filter를 열고 디버그 모드를 켠 뒤 백업에서 내보내세요.`n2. 내보낸 폴더를 다른 PC로 복사하세요.`n3. 다른 PC에 VST Ex Audio Filter와 같은 VST 플러그인을 설치하고 백업을 가져오세요.`n`n장치와 플러그인 이름은 PC마다 다를 수 있으며, 장면 모음은 OBS에서 따로 옮깁니다. 백업은 읽을 수 있는 형식이므로 직접 다시 설정할 수 있습니다." }
  id = @{ Title='Safe Uninstaller'; Language='Bahasa'; Folder='Folder instalasi'; Item='Item'; Kind='Keterangan'; Size='Ukuran'
    core='Diperlukan untuk berjalan'; settings='Pengaturan (simpan untuk instal ulang)'; generated='Dibuat otomatis (tidak perlu)'; old='Sisa versi lama (tidak perlu)'
    Backup='Cadangkan pengaturan...'; Move='Pindah ke PC lain'; Remove='Hapus item yang dicentang'; Close='Tutup'
    ObsRunning='OBS sedang berjalan. Tutup OBS untuk menghapus.'; Registered='Masih ada di Alat > Skrip pada: {0}. Hapus dulu di sana (pilih lalu tekan -).'; Ready='Siap. Item yang dicentang masuk ke Recycle Bin, jadi masih bisa dipulihkan.'
    NotFound='Tidak ditemukan file terpasang.'; Confirm='Pindahkan {0} item ke Recycle Bin?'; Done='{0} item dipindahkan ke Recycle Bin.'; Failed='Tidak dapat memindahkan: {0}'
    NoSettings='Tidak ada file pengaturan untuk dicadangkan.'; BackedUp='Disimpan ke:{0}{1}'; BackupPick='Pilih lokasi cadangan'
    MoveText="1. Buka skrip ini di Alat > Skrip, aktifkan Mode Debug, lalu tekan Ekspor pengaturan.`n2. Tekan juga Cadangkan pengaturan di sini.`n3. Salin keduanya ke PC lain.`n4. Pasang skrip di sana dan gunakan Impor pengaturan.`n`nNama perangkat bisa berbeda antar-PC. File .json yang diekspor dapat dibaca sehingga bisa diatur manual."
    MoveTextPlugin="1. Buka Alat > #cbOBScripts > VST Ex Audio Filter, aktifkan Mode debug, lalu ekspor lewat Cadangan.`n2. Salin folder hasil ekspor ke PC lain.`n3. Pasang VST Ex Audio Filter dan plugin VST yang sama di sana, lalu impor cadangan.`n`nNama perangkat dan plugin bisa berbeda antar-PC, dan koleksi adegan dipindahkan terpisah lewat OBS. Cadangan dapat dibaca sehingga bisa diatur manual." }
  fr = @{ Title='Désinstallateur sûr'; Language='Langue'; Folder="Dossier d'installation"; Item='Élément'; Kind='Nature'; Size='Taille'
    core='Nécessaire au fonctionnement'; settings='Vos réglages (à garder pour réinstaller)'; generated='Créé automatiquement (inutile)'; old='Reste une ancienne version (inutile)'
    Backup='Sauvegarder les réglages...'; Move='Passer à un autre PC'; Remove='Désinstaller les éléments cochés'; Close='Fermer'
    ObsRunning='OBS est ouvert. Fermez OBS pour désinstaller.'; Registered="Encore présent dans Outils > Scripts pour : {0}. Retirez-le d'abord (sélection puis -)."; Ready='Prêt. Les éléments cochés vont à la Corbeille et restent récupérables.'
    NotFound='Aucun fichier installé trouvé.'; Confirm='Déplacer {0} élément(s) vers la Corbeille ?'; Done='{0} élément(s) déplacé(s) vers la Corbeille.'; Failed='Déplacement impossible : {0}'
    NoSettings="Aucun fichier de réglages à sauvegarder."; BackedUp='Enregistré dans :{0}{1}'; BackupPick="Choisissez où enregistrer la sauvegarde"
    MoveText="1. Ouvrez ce script dans Outils > Scripts, activez le mode débogage et cliquez sur Exporter les réglages.`n2. Cliquez aussi ici sur Sauvegarder les réglages.`n3. Copiez les deux sur l'autre PC.`n4. Installez-y le script et utilisez Importer les réglages.`n`nLes noms de périphériques peuvent changer d'un PC à l'autre. Le .json exporté est lisible : vous pouvez les régler à la main."
    MoveTextPlugin="1. Ouvrez Outils > #cbOBScripts > VST Ex Audio Filter, activez le mode débogage et exportez depuis Sauvegarde.`n2. Copiez le dossier exporté sur l autre PC.`n3. Installez-y VST Ex Audio Filter et les mêmes plugins VST, puis importez la sauvegarde.`n`nLes noms de périphériques et de plugins peuvent changer d un PC à l autre, et les collections de scènes se déplacent à part avec OBS. La sauvegarde est lisible : vous pouvez tout régler à la main." }
  'zh-TW' = @{ Title='安全解除安裝工具'; Language='語言'; Folder='安裝資料夾'; Item='項目'; Kind='內容'; Size='大小'
    core='執行時需要'; settings='設定 (重新安裝時保留)'; generated='自動產生 (不需要)'; old='舊版本殘留 (不需要)'
    Backup='備份設定...'; Move='搬移到其他電腦'; Remove='解除安裝已勾選項目'; Close='關閉'
    ObsRunning='OBS 正在執行。請先關閉 OBS 再解除安裝。'; Registered='以下場景集合的 工具 > 腳本 中仍有此腳本: {0}。請先選取後按 - 移除。'; Ready='準備完成。已勾選項目會移到資源回收筒，之後仍可還原。'
    NotFound='找不到已安裝的檔案。'; Confirm='要將 {0} 個項目移到資源回收筒嗎？'; Done='已將 {0} 個項目移到資源回收筒。'; Failed='無法移動: {0}'
    NoSettings='沒有可備份的設定檔。'; BackedUp='已儲存至:{0}{1}'; BackupPick='請選擇備份的儲存位置'
    MoveText="1. 在 工具 > 腳本 開啟此腳本，開啟偵錯模式並按「匯出設定」。`n2. 也請按這裡的「備份設定」。`n3. 將兩者複製到其他電腦。`n4. 在該電腦安裝腳本並使用「匯入設定」。`n`n各電腦的裝置名稱可能不同。匯出的 .json 可直接閱讀，因此也能手動設定。"
    MoveTextPlugin="1. 開啟 工具 > #cbOBScripts > VST Ex Audio Filter，開啟偵錯模式，從備份匯出。`n2. 將匯出的資料夾複製到其他電腦。`n3. 在該電腦安裝 VST Ex Audio Filter 與相同的 VST 外掛，然後匯入備份。`n`n各電腦的裝置與外掛名稱可能不同，場景集合需另外透過 OBS 搬移。備份可直接閱讀，因此也能手動設定。" }
}

function Get-ObsLanguage {
  $root = Join-Path $env:APPDATA 'obs-studio'
  foreach ($ini in 'user.ini', 'global.ini') {
    $path = Join-Path $root $ini
    if (Test-Path -LiteralPath $path) {
      $m = Select-String -LiteralPath $path -Pattern '^Language=(.+)$' | Select-Object -First 1
      if ($m) {
        $code = $m.Matches[0].Groups[1].Value.Trim()
        foreach ($key in 'zh-TW', 'ja', 'ko', 'id', 'fr') { if ($code -like "$key*") { return $key } }
        return 'en'
      }
    }
  }
  return 'en'
}

# Scene collections keep each registered script's path, which also finds copies from old installs.
function Get-Registrations($scenesDir) {
  $found = @()
  $mains = @($Config.main) + @($Config.oldMains) | Where-Object { $_ }
  if (-not $mains) { return $found }
  if (-not (Test-Path -LiteralPath $scenesDir)) { return $found }
  foreach ($file in Get-ChildItem -LiteralPath $scenesDir -Filter '*.json' -File) {
    try {
      $json = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName | ConvertFrom-Json
      foreach ($script in @($json.modules.'scripts-tool')) {
        if ($script.path -and ($mains -contains (Split-Path -Leaf $script.path))) {
          $found += [pscustomobject]@{ Collection = $json.name; Dir = (Split-Path -Parent $script.path).Replace('/', '\') }
        }
      }
    } catch { continue } # a damaged collection must not stop the uninstaller
  }
  return $found
}

function Test-SafeName($name) {
  return ($name -notmatch '[\\/:*?"<>|]') -and ($name -notmatch '^\.+$') -and ($name.Trim() -ne '')
}

# A base of "config" is OBS's plugin settings folder. "data" is the folder the user chose for a plugin's pictures,
# which only counts when it differs from that plugin's settings folder.
function Get-ItemBase($entry, $dir) {
  if ($entry.base -eq 'config') { return $script:ConfigRoot }
  if ($entry.base -ne 'data') { return $dir }
  $own = Join-Path $script:ConfigRoot $entry.owner
  try {
    $chosen = (Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $own 'plugin-meta.json') | ConvertFrom-Json).ui.dataDir
  } catch { return $null }
  if (-not $chosen) { return $null }
  $chosen = $chosen.Replace('/', '\').TrimEnd('\')
  if ($chosen -ieq $own) { return $null }
  return $chosen
}

function Get-Items($dir) {
  $items = @()
  foreach ($entry in $Config.items) {
    if (-not (Test-SafeName $entry.name)) { continue }
    $base = Get-ItemBase $entry $dir
    if (-not $base) { continue }
    $path = Join-Path $base $entry.name
    if (-not (Test-Path -LiteralPath $path)) { continue }
    $info = Get-Item -LiteralPath $path -Force
    if ($info.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue } # never follow links out of the folder
    $size = if ($info.PSIsContainer) { (Get-ChildItem -LiteralPath $path -Recurse -File -Force | Measure-Object Length -Sum).Sum } else { $info.Length }
    $items += [pscustomobject]@{ Name = $entry.name; Kind = $entry.kind; Path = $path; Size = [long]$size; IsDir = $info.PSIsContainer }
  }
  return $items
}

function Get-InstallDirs($registrations) {
  $dirs = @($Root) + @($registrations | ForEach-Object { $_.Dir })
  return @($dirs | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Sort-Object -Unique | Where-Object { @(Get-Items $_).Count -gt 0 })
}

function Remove-ToRecycleBin($item) {
  if ($item.IsDir) {
    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($item.Path, 'OnlyErrorDialogs', 'SendToRecycleBin')
  } else {
    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($item.Path, 'OnlyErrorDialogs', 'SendToRecycleBin')
  }
}

function Backup-Settings($items, $target) {
  $dest = Join-Path $target ("{0}-backup-{1}" -f ($Config.app -replace '[^A-Za-z0-9]+', '_'), (Get-Date -Format 'yyyyMMdd-HHmmss'))
  New-Item -ItemType Directory -Path $dest | Out-Null
  foreach ($item in $items) { Copy-Item -LiteralPath $item.Path -Destination $dest -Recurse }
  return $dest
}

Add-Type -AssemblyName Microsoft.VisualBasic

# Run with -SelfTest <empty folder> from the release checklist: it asserts the rules above without any window.
if ($SelfTest) {
  $probe = Join-Path $SelfTest 'probe'
  $script:ConfigRoot = Join-Path $SelfTest 'config'
  New-Item -ItemType Directory -Path $probe, $script:ConfigRoot | Out-Null
  $listed = @($Config.items | Where-Object { $_.base -ne 'data' })
  foreach ($entry in $listed) { Set-Content -LiteralPath (Join-Path (Get-ItemBase $entry $probe) $entry.name) -Value 'x' }
  Set-Content -LiteralPath (Join-Path $probe 'keep_me.txt') -Value 'x'
  $items = @(Get-Items $probe)
  if ($items.Count -ne $listed.Count) { throw 'listed items were not found' }
  if ($items.Name -contains 'keep_me.txt') { throw 'an unlisted file was offered' }
  foreach ($bad in '..', '..\x', 'a/b', 'C:\Windows') { if (Test-SafeName $bad) { throw "unsafe name accepted: $bad" } }
  if ($Config.main) {
    $scenes = Join-Path $SelfTest 'scenes'
    New-Item -ItemType Directory -Path $scenes | Out-Null
    foreach ($name in @($Config.main) + @($Config.oldMains) | Where-Object { $_ }) {
      $scene = @{ name = 'test'; modules = @{ 'scripts-tool' = @(@{ path = (Join-Path $probe $name).Replace('\', '/') }) } }
      $scene | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $scenes "$name.json") -Encoding UTF8
    }
    $expected = @(@($Config.main) + @($Config.oldMains) | Where-Object { $_ }).Count
    if (@(Get-Registrations $scenes).Count -ne $expected) { throw 'a registered script name was not found' }
  }
  $saved = @($items | Where-Object Kind -eq 'settings')
  $backup = Backup-Settings $saved $SelfTest
  foreach ($item in $saved) { if (-not (Test-Path -LiteralPath (Join-Path $backup $item.Name))) { throw 'backup is missing a file' } }
  foreach ($item in $items) { Remove-ToRecycleBin $item }
  if (@(Get-Items $probe).Count -ne 0) { throw 'items were left behind' }
  if (-not (Test-Path -LiteralPath (Join-Path $probe 'keep_me.txt'))) { throw 'an unlisted file was removed' }
  'SELFTEST OK: ' + $Config.app
  exit 0
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:Lang = Get-ObsLanguage
function T($key) { return $Text[$script:Lang][$key] }

$registrations = @(Get-Registrations (Join-Path $env:APPDATA 'obs-studio\basic\scenes'))
$installDirs = @(Get-InstallDirs $registrations)

$form = New-Object System.Windows.Forms.Form
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object System.Drawing.Size(790, 500)
$form.MinimumSize = New-Object System.Drawing.Size(806, 420)
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)

$langLabel = New-Object System.Windows.Forms.Label
$langLabel.Location = '12,15'; $langLabel.AutoSize = $true
$langBox = New-Object System.Windows.Forms.ComboBox
$langBox.Location = '152,12'; $langBox.Width = 200; $langBox.DropDownStyle = 'DropDownList'
$langNames = [ordered]@{ en = 'English'; ja = '日本語'; ko = '한국어'; id = 'Bahasa Indonesia'; fr = 'Français'; 'zh-TW' = '繁體中文' }
[void]$langBox.Items.AddRange([object[]]@($langNames.Values))

$folderLabel = New-Object System.Windows.Forms.Label
$folderLabel.Location = '12,49'; $folderLabel.AutoSize = $true
$folderBox = New-Object System.Windows.Forms.ComboBox
$folderBox.Location = '152,46'; $folderBox.Width = 626; $folderBox.DropDownStyle = 'DropDownList'; $folderBox.Anchor = 'Top,Left,Right'
if ($installDirs.Count) { [void]$folderBox.Items.AddRange([object[]]$installDirs) }

$list = New-Object System.Windows.Forms.ListView
$list.Location = '12,82'; $list.Size = New-Object System.Drawing.Size(766, 280); $list.Anchor = 'Top,Bottom,Left,Right'
$list.View = 'Details'; $list.CheckBoxes = $true; $list.FullRowSelect = $true
[void]$list.Columns.Add('', 330); [void]$list.Columns.Add('', 290); [void]$list.Columns.Add('', 90)

$status = New-Object System.Windows.Forms.Label
$status.Location = '12,370'; $status.Size = New-Object System.Drawing.Size(766, 70); $status.Anchor = 'Bottom,Left,Right'

$backupBtn = New-Object System.Windows.Forms.Button
$moveBtn = New-Object System.Windows.Forms.Button
$removeBtn = New-Object System.Windows.Forms.Button
$closeBtn = New-Object System.Windows.Forms.Button
$x = 12
foreach ($b in $backupBtn, $moveBtn, $removeBtn, $closeBtn) {
  $b.Location = New-Object System.Drawing.Point($x, 450); $b.Height = 36; $b.Anchor = 'Bottom,Left'
  $b.Width = if ($b -eq $removeBtn) { 280 } elseif ($b -eq $closeBtn) { 80 } else { 200 }
  $x += $b.Width + 6
}
$form.Controls.AddRange(@($langLabel, $langBox, $folderLabel, $folderBox, $list, $status, $backupBtn, $moveBtn, $removeBtn, $closeBtn))

function Format-Size([long]$bytes) {
  if ($bytes -ge 1MB) { return '{0:N1} MB' -f ($bytes / 1MB) }
  return '{0:N0} KB' -f [math]::Ceiling($bytes / 1KB)
}

function Update-State {
  $obs = @(Get-Process -Name 'obs64', 'obs32', 'obs' -ErrorAction SilentlyContinue)
  $hasItems = $list.Items.Count -gt 0
  $removeBtn.Enabled = $hasItems -and ($obs.Count -eq 0)
  $backupBtn.Enabled = $hasItems
  $dir = [string]$folderBox.SelectedItem
  $here = @($registrations | Where-Object { $_.Dir -ieq $dir } | ForEach-Object { $_.Collection } | Sort-Object -Unique)
  $lines = @()
  if (-not $hasItems) { $lines += T 'NotFound' }
  elseif ($obs.Count) { $lines += T 'ObsRunning' }
  if ($here.Count) { $lines += (T 'Registered') -f ($here -join ', ') }
  if ($hasItems -and -not $obs.Count -and -not $here.Count) { $lines += T 'Ready' }
  $status.Text = $lines -join "`n"
}

function Update-List {
  $list.Items.Clear()
  if ($folderBox.SelectedItem) {
    foreach ($item in Get-Items ([string]$folderBox.SelectedItem)) {
      $row = New-Object System.Windows.Forms.ListViewItem($item.Name)
      [void]$row.SubItems.Add((T $item.Kind))
      [void]$row.SubItems.Add((Format-Size $item.Size))
      $row.Tag = $item
      $row.Checked = $item.Kind -ne 'settings' # settings stay unless the user decides otherwise
      [void]$list.Items.Add($row)
    }
  }
  Update-State
}

function Update-Language {
  $form.Text = "$($Config.app) - $(T 'Title')"
  $langLabel.Text = T 'Language'
  $folderLabel.Text = T 'Folder'
  $list.Columns[0].Text = T 'Item'; $list.Columns[1].Text = T 'Kind'; $list.Columns[2].Text = T 'Size'
  $backupBtn.Text = T 'Backup'; $moveBtn.Text = T 'Move'; $removeBtn.Text = T 'Remove'; $closeBtn.Text = T 'Close'
  Update-List
}

$langBox.Add_SelectedIndexChanged({ $script:Lang = @($langNames.Keys)[$langBox.SelectedIndex]; Update-Language })
$folderBox.Add_SelectedIndexChanged({ Update-List })
$closeBtn.Add_Click({ $form.Close() })
$moveBtn.Add_Click({
  $key = if ($Config.moveText) { $Config.moveText } else { 'MoveText' }
  [void][System.Windows.Forms.MessageBox]::Show((T $key), (T 'Move'))
})

$backupBtn.Add_Click({
  $saved = @($list.Items | ForEach-Object { $_.Tag } | Where-Object Kind -eq 'settings')
  if (-not $saved.Count) { [void][System.Windows.Forms.MessageBox]::Show((T 'NoSettings'), (T 'Title')); return }
  $pick = New-Object System.Windows.Forms.FolderBrowserDialog
  $pick.Description = T 'BackupPick'
  if ($pick.ShowDialog($form) -ne 'OK') { return }
  try {
    $dest = Backup-Settings $saved $pick.SelectedPath
    [void][System.Windows.Forms.MessageBox]::Show(((T 'BackedUp') -f "`n", $dest), (T 'Title'))
  } catch { [void][System.Windows.Forms.MessageBox]::Show(((T 'Failed') -f $_.Exception.Message), (T 'Title')) }
})

$removeBtn.Add_Click({
  $checked = @($list.CheckedItems | ForEach-Object { $_.Tag })
  if (-not $checked.Count) { return }
  if (@(Get-Process -Name 'obs64', 'obs32', 'obs' -ErrorAction SilentlyContinue).Count) { Update-State; return }
  $answer = [System.Windows.Forms.MessageBox]::Show(((T 'Confirm') -f $checked.Count), (T 'Title'), 'YesNo', 'Warning', 'Button2')
  if ($answer -ne 'Yes') { return }
  $moved = 0; $failed = @()
  foreach ($item in $checked) {
    try { Remove-ToRecycleBin $item; $moved++ } catch { $failed += $item.Name }
  }
  Update-List
  $message = (T 'Done') -f $moved
  if ($failed.Count) { $message += "`n" + ((T 'Failed') -f ($failed -join ', ')) }
  [void][System.Windows.Forms.MessageBox]::Show($message, (T 'Title'))
})

$index = @($langNames.Keys).IndexOf($script:Lang)
if ($folderBox.Items.Count) { $folderBox.SelectedIndex = 0 }
$langBox.SelectedIndex = $index
Update-Language
[void]$form.ShowDialog()
