Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Design

# ComboBox выбора EXE: если в списке 0 или 1 элемент, выбирать не из чего —
# поэтому кнопка-стрелка скрывается (закрашивается цветом фона) и раскрытие
# списка блокируется. Как только в список добавляют второй элемент (в том числе
# вручную через "Обзор..."), стрелка появляется сама: следим за сообщениями
# CB_ADDSTRING / CB_INSERTSTRING / CB_DELETESTRING / CB_RESETCONTENT.
Add-Type -ReferencedAssemblies @('System.Drawing','System.Windows.Forms') -TypeDefinition @'
using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class SmartExeComboBox : ComboBox
{
    private const int WM_PAINT = 0x000F;
    private const int WM_KEYDOWN = 0x0100;
    private const int WM_SYSKEYDOWN = 0x0104;
    private const int WM_LBUTTONDOWN = 0x0201;
    private const int WM_LBUTTONDBLCLK = 0x0203;
    private const int CB_ADDSTRING = 0x0143;
    private const int CB_DELETESTRING = 0x0144;
    private const int CB_INSERTSTRING = 0x014A;
    private const int CB_RESETCONTENT = 0x014B;
    private const int CB_SHOWDROPDOWN = 0x014F;
    private const int VK_F4 = 0x73;
    private const int VK_DOWN = 0x28;
    private const int VK_UP = 0x26;

    [DllImport("uxtheme.dll", ExactSpelling = true, CharSet = CharSet.Unicode)]
    private static extern int SetWindowTheme(IntPtr hWnd, string pszSubAppName, string pszSubIdList);

    // Пока список пустой/с одним элементом, стрелку не только закрашиваем,
    // но и полностью отключаем тему (visual styles) для контрола. Иначе при
    // наведении курсора Windows проигрывает анимацию hot-tracking кнопки
    // через UxTheme/BufferedPaint отдельно от WM_PAINT, и на долю секунды
    // успевает мелькнуть настоящая стрелка, прежде чем мы её перекрываем.
    // Без темы кнопка рисуется классическим стилем прямо внутри WM_PAINT —
    // никакой отдельной анимации наведения, перекрытие срабатывает всегда.
    private bool? _themed;

    private void UpdateTheme()
    {
        if (!IsHandleCreated) return;
        bool wantThemed = !ArrowHidden;
        if (_themed == wantThemed) return;
        _themed = wantThemed;
        SetWindowTheme(Handle, wantThemed ? null : "", wantThemed ? null : "");
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        _themed = null;
        UpdateTheme();
    }

    public bool ArrowHidden
    {
        get { return Items.Count <= 1; }
    }

    protected override void WndProc(ref Message m)
    {
        if (ArrowHidden)
        {
            if (m.Msg == WM_LBUTTONDOWN || m.Msg == WM_LBUTTONDBLCLK) { return; }
            if (m.Msg == CB_SHOWDROPDOWN && m.WParam != IntPtr.Zero) { return; }
            if (m.Msg == WM_KEYDOWN || m.Msg == WM_SYSKEYDOWN)
            {
                int vk = m.WParam.ToInt32();
                if (vk == VK_F4 || vk == VK_DOWN || vk == VK_UP) { return; }
            }
        }

        base.WndProc(ref m);

        if (m.Msg == CB_ADDSTRING || m.Msg == CB_INSERTSTRING ||
            m.Msg == CB_DELETESTRING || m.Msg == CB_RESETCONTENT)
        {
            UpdateTheme();
            Invalidate();
        }
        else if (m.Msg == WM_PAINT && ArrowHidden)
        {
            int w = SystemInformation.VerticalScrollBarWidth + 2;
            using (Graphics g = Graphics.FromHwnd(Handle))
            using (SolidBrush b = new SolidBrush(BackColor))
            {
                g.FillRectangle(b, new Rectangle(Width - w - 1, 1, w, Height - 2));
            }
        }
    }
}
'@

Add-Type -ReferencedAssemblies @('System.Drawing','System.Windows.Forms') -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

public class SteamToggleSwitch : Control
{
    private bool _checked;
    public event EventHandler CheckedChanged;

    public bool Checked
    {
        get { return _checked; }
        set
        {
            if (_checked == value) return;
            _checked = value;
            Invalidate();
            if (CheckedChanged != null) CheckedChanged(this, EventArgs.Empty);
        }
    }

    public SteamToggleSwitch()
    {
        SetStyle(ControlStyles.UserPaint |
                 ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.OptimizedDoubleBuffer |
                 ControlStyles.ResizeRedraw |
                 ControlStyles.SupportsTransparentBackColor, true);
        TabStop = false;
        Cursor = Cursors.Hand;
        BackColor = Color.Transparent;
        Size = new Size(42, 24);
        Margin = new Padding(0);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.CompositingQuality = CompositingQuality.HighQuality;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        g.Clear(Parent != null ? Parent.BackColor : Color.Transparent);

        int w = Width - 1;
        int h = Height - 1;
        float r = h / 2f;

        using (GraphicsPath track = new GraphicsPath())
        using (SolidBrush trackBrush = new SolidBrush(
            _checked ? Color.FromArgb(30, 144, 230) : Color.FromArgb(65, 72, 82)))
        {
            track.AddArc(0, 0, h, h, 90, 180);
            track.AddArc(w - h, 0, h, h, 270, 180);
            track.CloseFigure();
            g.FillPath(trackBrush, track);
        }

        int knob = h - 4;
        int x = _checked ? (w - knob - 2) : 2;
        int y = 2;
        using (SolidBrush knobBrush = new SolidBrush(Color.White))
        {
            g.FillEllipse(knobBrush, x, y, knob, knob);
        }
    }
}
'@


# SteamGridDB/Steam network calls run inside WinForms. PowerShell 5.1 can show its own
# host progress window for Invoke-WebRequest; that window blocks/competes with our dialogs
# and is especially confusing when several requests happen in sequence. Never show it.
$ProgressPreference = 'SilentlyContinue'


# ===================== СОВРЕМЕННЫЙ ДИАЛОГ ВЫБОРА ПАПКИ =====================
# Раньше выбор папки шёл через System.Windows.Forms.FolderBrowserDialog —
# это древний "SHBrowseForFolder" диалог 90-х с деревом папок без адресной
# строки, избранного, поиска и т.п. Ниже — обёртка над нативным COM-интерфейсом
# IFileOpenDialog с флагом FOS_PICKFOLDERS: это ТОТ ЖЕ современный диалог
# Проводника, что использует сам Windows (и как в обычном "Открыть файл"),
# только настроенный на выбор папки, а не файла — без каких-либо "хаков".
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace ModernDialogs
{
    [ComImport]
    [Guid("DC1C5A9C-E88A-4dde-A5A1-60F82A20AEF7")]
    internal class FileOpenDialogRCW { }

    [ComImport]
    [Guid("d57c7288-d4ad-4768-be02-9d969532d960")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IFileOpenDialog
    {
        [PreserveSig] int Show(IntPtr parent);
        void SetFileTypes(uint cFileTypes, IntPtr rgFilterSpec);
        void SetFileTypeIndex(uint iFileType);
        void GetFileTypeIndex(out uint piFileType);
        void Advise(IntPtr pfde, out uint pdwCookie);
        void Unadvise(uint dwCookie);
        void SetOptions(uint fos);
        void GetOptions(out uint fos);
        void SetDefaultFolder(IShellItem psi);
        void SetFolder(IShellItem psi);
        void GetFolder(out IShellItem ppsi);
        void GetCurrentSelection(out IShellItem ppsi);
        void SetFileName([MarshalAs(UnmanagedType.LPWStr)] string pszName);
        void GetFileName([MarshalAs(UnmanagedType.LPWStr)] out string pszName);
        void SetTitle([MarshalAs(UnmanagedType.LPWStr)] string pszTitle);
        void SetOkButtonLabel([MarshalAs(UnmanagedType.LPWStr)] string pszText);
        void SetFileNameLabel([MarshalAs(UnmanagedType.LPWStr)] string pszLabel);
        void GetResult(out IShellItem ppsi);
        void AddPlace(IShellItem psi, uint alignment);
        void SetDefaultExtension([MarshalAs(UnmanagedType.LPWStr)] string pszDefaultExtension);
        void Close(int hr);
        void SetClientGuid(ref Guid guid);
        void ClearClientData();
        void SetFilter(IntPtr pFilter);
        void GetResults(out IntPtr ppenum);
        void GetSelectedItems(out IntPtr ppsai);
    }

    [ComImport]
    [Guid("43826d1e-e718-42ee-bc55-a1e261c37bfe")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IShellItem
    {
        void BindToHandler(IntPtr pbc, ref Guid bhid, ref Guid riid, out IntPtr ppv);
        void GetParent(out IShellItem ppsi);
        void GetDisplayName(uint sigdnName, out IntPtr ppszName);
        void GetAttributes(uint sfgaoMask, out uint psfgaoAttribs);
        void Compare(IShellItem psi, uint hint, out int piOrder);
    }

    public class VistaFolderBrowserDialog
    {
        public string SelectedPath = "";
        public string Description = "";

        private const uint FOS_PICKFOLDERS = 0x00000020;
        private const uint FOS_FORCEFILESYSTEM = 0x00000040;
        private const uint FOS_NOVALIDATE = 0x00000100;
        private const uint FOS_NOTESTFILECREATE = 0x00010000;
        private const uint FOS_DONTADDTORECENT = 0x02000000;
        private const uint SIGDN_FILESYSPATH = 0x80058000;

        [DllImport("shell32.dll", CharSet = CharSet.Unicode, PreserveSig = false)]
        private static extern void SHCreateItemFromParsingName(
            [MarshalAs(UnmanagedType.LPWStr)] string path,
            IntPtr pbc,
            [MarshalAs(UnmanagedType.LPStruct)] Guid riid,
            out IShellItem shellItem);

        public bool ShowDialog(IntPtr owner)
        {
            IFileOpenDialog dialog = (IFileOpenDialog)new FileOpenDialogRCW();
            try
            {
                uint options;
                dialog.GetOptions(out options);
                options |= FOS_PICKFOLDERS | FOS_FORCEFILESYSTEM | FOS_NOVALIDATE | FOS_NOTESTFILECREATE | FOS_DONTADDTORECENT;
                dialog.SetOptions(options);

                if (!string.IsNullOrEmpty(Description)) dialog.SetTitle(Description);

                if (!string.IsNullOrEmpty(SelectedPath) && System.IO.Directory.Exists(SelectedPath))
                {
                    try
                    {
                        IShellItem startItem;
                        SHCreateItemFromParsingName(SelectedPath, IntPtr.Zero, typeof(IShellItem).GUID, out startItem);
                        if (startItem != null) dialog.SetFolder(startItem);
                    }
                    catch { }
                }

                int hr = dialog.Show(owner);
                if (hr != 0) { return false; }

                IShellItem resultItem;
                dialog.GetResult(out resultItem);
                IntPtr pathPtr;
                resultItem.GetDisplayName(SIGDN_FILESYSPATH, out pathPtr);
                SelectedPath = Marshal.PtrToStringUni(pathPtr);
                Marshal.FreeCoTaskMem(pathPtr);
                Marshal.ReleaseComObject(resultItem);
                return true;
            }
            finally
            {
                Marshal.ReleaseComObject(dialog);
            }
        }
    }
}
'@ -ReferencedAssemblies System.Windows.Forms

$global:dirC = ""
$global:dirD = ""
# Единая версия приложения — используется в заголовке главного окна, в
# подписи внизу окна настроек и в User-Agent HTTP-запросов. Меняйте только
# здесь при выпуске новой версии.
$global:appVersion = "1.0.1"
$global:appTitle = "Steam Commander"

# ===================== ЛОКАЛИЗАЦИЯ =====================
# Все видимые пользователю строки берутся из таблицы $script:I18n через T:
#   T 'ключ'              — простая строка
#   T 'ключ' @($a, $b)    — строка с подстановкой {0}, {1}, ... (оператор -f)
# Язык хранится в $global:language ('ru' / 'en' / 'zh' / 'es' / 'pt' / 'de'), сохраняется в config.ini
# (строка language=) и выбирается в «Настройках». Если ключа нет в выбранном
# языке — берётся русский текст, если нет и его — сам ключ (так сразу видно,
# что строку забыли добавить). Чтобы добавить язык, достаточно завести ещё
# одну ветку в $script:I18n и строку в $script:languageList.
$global:language = ''
# Steam — название языка в терминах Steam (API-имя: english, russian, german,
# french, spanish, schinese, japanese и т.д.). По нему берутся локализованные
# обложки/логотипы игры. Для нового языка интерфейса достаточно указать его тут.
$script:languageList = @(
    [PSCustomObject]@{ Code = 'ru'; Name = 'Русский'; Steam = 'russian' },
    [PSCustomObject]@{ Code = 'en'; Name = 'English'; Steam = 'english' },
    [PSCustomObject]@{ Code = 'zh'; Name = '简体中文'; Steam = 'schinese' },
    [PSCustomObject]@{ Code = 'es'; Name = 'Español'; Steam = 'spanish' },
    [PSCustomObject]@{ Code = 'pt'; Name = 'Português (Brasil)'; Steam = 'brazilian' },
    [PSCustomObject]@{ Code = 'de'; Name = 'Deutsch'; Steam = 'german' }
)
$script:I18n = @{
    ru = @{
        hint_main = 'Двойной клик / Enter — карточка игры'
        panel_extra = 'Папка'
        panel_main = 'Папка'
        panel_free = '{0} [Свободно: {1} {2}]'
        unit_gb = 'ГБ'
        unit_mb = 'МБ'
        unit_kb = 'КБ'
        unit_b = 'Б'
        path_prefix = 'Путь: '
        browse = 'Обзор...'
        search_cue = 'Поиск по названию папки…'
        empty_main = 'Выберите основную папку библиотеки с Non-Steam Games'
        empty_extra = 'Выберите дополнительную папку с Non-Steam Games (используется для временного переноса на быстрый SSD накопитель)'
        nothing_found = 'Ничего не найдено по запросу «{0}»'
        col_name = 'Имя'
        col_size = 'Размер'
        col_date = 'Дата'
        col_lib = '✓'
        col_file = 'Файл'
        btn_move = 'Перенести игру'
        btn_refresh = 'Обновить'
        batch_auto = 'Автозаполнение карточек'
        batch_auto_tip = 'Если включено: при пакетном добавлении игры с уверенно определёнными названием и exe добавляются в библиотеку автоматически, без показа карточки. Карточка откроется только для игр, которые программа не смогла определить однозначно.'
        btn_add_batch = '＋  Добавить выбранные игры в библиотеку'
        btn_add_batch_n = '＋  Добавить выбранные игры в библиотеку ({0})'
        tip_select_all = 'Отметить все игры в списке / снять все отметки'
        tip_lib_header = 'В библиотеке Steam (клик — сортировка)'
        tip_row_check = 'Отметить игру (для переноса или пакетного добавления)'
        tip_row_installed = 'Игра уже добавлена в библиотеку Steam'
        settings_title = 'Настройки'
        settings_desc = 'Открыть настройки программы'
        pick_extra_folder = 'Выберите папку'
        pick_main_folder = 'Выберите папку'
        st_sizes_sort = 'Считаю размер папок для сортировки: {0} ({1} из {2})'
        st_move_first = 'Сначала отметьте галочкой игру для переноса.'
        target_main = 'целевую папку'
        target_extra = 'целевую папку'
        msg_no_space = 'Недостаточно места на {0}!'
        err_junction = 'Не удалось обработать перемещение: {0}'
        move_title = 'ПЕРЕНОС'
        st_copy_progress = '{0}: {1} [Скорость: {2} МБ/с] [{3}%]'
        st_copy_done = '{0}: {1} [100%] — завершено'
        st_move_done = 'Готово: перенесено {0} из {1} на {2}.'
        st_move_err = 'Ошибка переноса: {0}'
        st_refresh_start = 'Обновление библиотеки Steam…'
        st_refresh_done = 'Библиотека Steam обновлена.'
        st_refresh_err = 'Ошибка обновления: {0}'
        st_sizes_checked = 'Считаю размер отмеченных: {0} ({1} из {2})'
        st_checked_total = 'Отмечено игр: {0} — общий размер: {1} {2}'
        st_size_one = 'Размер «{0}»: {1} {2}'
        st_panel_sizes = 'Посчитан размер всех папок панели ({0}) — итого: {1} {2}'
        st_removed = 'Убрано из списка: {0}. Файлы на диске не тронуты; кнопка «Обновить» вернёт игры в список.'
        set_language = 'Язык'
        set_steam_folder = 'Папка Steam'
        set_profile = 'Профиль'
        set_profile_hint = 'Выберите userdata-профиль, с которым будет работать программа.'
        set_api_key = 'API-ключ'
        key_valid = 'API-ключ действителен.'
        key_invalid_default = 'API-ключ недействителен или не прошёл проверку.'
        key_empty = 'API-ключ не введён.'
        key_checking = 'Проверяю ключ…'
        key_hint_default = 'Нужен для загрузки обложек игр. Бесплатный ключ можно получить на steamgriddb.com/profile/preferences.'
        key_new_key = ' Новый ключ: steamgriddb.com/profile/preferences.'
        sg_401 = 'Ключ недействителен или отозван (401).'
        sg_403 = 'Доступ запрещён (403): ключ отозван или запрос заблокирован сервисом.'
        sg_429 = 'Слишком много запросов к SteamGridDB (429). Повторите проверку позже.'
        sg_server = 'Сервис SteamGridDB временно недоступен (ошибка {0}).'
        sg_other = 'Неожиданный ответ SteamGridDB (код {0}).'
        sg_dns = 'Не удаётся найти сервер steamgriddb.com (проблема с DNS или интернетом).'
        sg_timeout = 'SteamGridDB не ответил за 10 секунд.'
        sg_tls = 'Ошибка защищённого соединения (TLS) с SteamGridDB.'
        sg_connect = 'Не удалось подключиться к SteamGridDB (соединение прервано или нет интернета).'
        sg_noresp = 'Нет ответа от SteamGridDB: {0}'
        set_backup_section = 'Резервные копии shortcuts.vdf'
        set_backup_current = 'Текущая папка: {0}'
        set_create_backup = 'Создать бэкап'
        set_restore = 'Восстановить'
        set_cancel = 'Отмена'
        set_save = 'Сохранить'
        set_no_profiles = 'Профили Steam не найдены'
        set_profile_none = 'В выбранной папке нет userdata-профилей.'
        set_profile_auto = 'Профиль выбран автоматически. Его можно изменить.'
        set_profile_chosen = 'Выбран профиль: {0}'
        set_profiles_fail = 'Не удалось прочитать профили'
        pick_steam_folder = 'Выберите папку установки Steam'
        pick_backup_folder = 'Выберите папку для резервных копий'
        no_backups = 'Резервных копий пока нет'
        confirm_title = 'Восстановление'
        confirm_q = 'Восстановить shortcuts.vdf из копии «{0}»?'
        confirm_note = 'Steam будет закрыт, файл заменён и затем Steam будет запущен снова.'
        bk_no_source = 'Для этой копии не найден исходный shortcuts.vdf.'
        bk_ready = 'Готово к восстановлению.'
        bk_created = 'Создано копий: {0}'
        bk_vdf_missing = 'Файл shortcuts.vdf не найден.'
        bk_closing = 'Закрытие Steam...'
        bk_no_steam_path = 'Не удалось определить путь к Steam.'
        bk_restoring = 'Восстановление файла...'
        bk_starting = 'Запуск Steam...'
        bk_restored_ok = 'Восстановлено и Steam перезапущен: {0}'
        bk_restored_nosteam = 'Файл восстановлен, но Steam не удалось запустить автоматически.'
        bk_restore_err = 'Ошибка восстановления: {0}'
        set_path_empty = 'Укажите папку установки Steam.'
        set_path_missing = 'Указанная папка Steam не существует.'
        set_exe_missing = 'В выбранной папке не найден steam.exe.'
        set_save_err = 'Не удалось сохранить настройки: {0}'
        vdf_eof = 'Файл VDF обрезан/повреждён (неожиданный конец данных)'
        vdf_eof_key = 'Файл VDF обрезан/повреждён (не найден конец имени ключа)'
        vdf_eof_str = 'Файл VDF обрезан/повреждён (не найден конец строкового значения)'
        vdf_eof_int = 'Файл VDF обрезан/повреждён (не хватает байт для int32)'
        vdf_bad_field = 'Неизвестный тип поля VDF: 0x{0} на позиции {1}'
        vdf_bad_type_key = 'Поле ''{0}'' имеет неожиданный тип VDF.'
        vdf_bad_type = 'Неизвестный тип VDF: 0x{0}.'
        sc_not_found = 'Существующий ярлык Steam не найден.'
        sc_file_missing = 'Файл shortcuts.vdf не найден: {0}'
        sc_no_node = 'В файле shortcuts.vdf не найден объект ''shortcuts''.'
        sc_target_gone = 'Ярлык для редактирования исчез из shortcuts.vdf.'
        sc_exists = 'Игра «{0}» уже есть в библиотеке Steam.'
        sc_userdata_missing = 'Папка ''{0}'' не найдена.'
        sc_node_corrupt = 'В файле shortcuts.vdf не найден объект ''shortcuts'' — файл повреждён или имеет неожиданный формат. Восстановите его из созданной вручную резервной копии.'
        exe_dlg_title = 'Выбор запуска — {0}'
        exe_dlg_hint = 'Найдено несколько исполняемых файлов. Выберите нужный:'
        exe_dlg_col = 'Путь к файлу'
        exe_dlg_ok = 'Подтвердить'
        exe_outside = 'Выберите исполняемый файл только из папки игры или её подпапок.'
        exe_outside_title = 'Недопустимый путь'
        ofd_title = 'Выберите EXE или BAT-файл игры'
        ofd_filter = 'Исполняемые файлы (*.exe;*.bat)|*.exe;*.bat|EXE (*.exe)|*.exe|BAT (*.bat)|*.bat'
        reason_title_unconfirmed = 'Название не подтверждено автоматически.'
        reason_exe_missing = 'Исполняемый файл не найден.'
        reason_multi_exe = 'Найдено несколько исполняемых файлов — выбор не гарантирован.'
        reason_shortcut_fail = 'Не удалось создать ярлык Steam.'
        reason_save_shortcut = 'Не удалось сохранить ярлык Steam.'
        sgdb_chooser_hint = 'Выберите вариант. Сначала показаны самые популярные. Загрузка миниатюр идёт в фоне.'
        src_tip_steam = 'Источник: Steam'
        src_tip_sgdb = 'Источник: SteamGridDB'
        sl_no_appid = 'App ID не указан — официальные обложки Steam недоступны.'
        sl_steam_fetch = 'Получаю официальные ресурсы Steam для App ID {0}…'
        sl_steam_found = 'Steam: найдено ресурсов — {0} из 4.'
        covlang_tip = 'Регион обложек Steam: {0}. Нажмите, чтобы выбрать другой.'
        covlang_no_appid = 'Регион обложек: сначала нужен App ID игры.'
        covlang_checking = 'Определяю доступные регионы обложек…'
        covlang_unavailable = 'Не удалось определить доступные регионы обложек для этой игры.'
        covlang_only_one = 'Для этой игры доступен только один регион обложек: {0}.'
        covlang_pick = 'Выберите регион обложек.'
        covlang_loading = 'Загружаю обложки региона «{0}»…'
        covlang_done = 'Регион обложек: {0}. Обновлено ресурсов: {1}.'
        covlang_fail = 'Не удалось загрузить обложки региона «{0}».'
        covlang_all_sgdb = 'Все обложки выбраны из SteamGridDB — менять регион Steam нечего.'
        sl_steam_fail = 'Steam: не удалось получить ресурсы ({0}).'
        sl_sg_nokey = 'SteamGridDB: API-ключ не задан.'
        sl_sg_keysaved = 'SteamGridDB: API-ключ сохранён.'
        sl_sg_need_name = 'SteamGridDB: укажите название или App ID.'
        sl_sg_variants = 'SteamGridDB: получаю варианты для «{0}»…'
        sl_sg_nocovers = 'SteamGridDB: у «{0}» нет доступных обложек.'
        sl_sg_by_id = 'SteamGridDB: ищу по App ID {0}…'
        sl_sg_id_none = 'SteamGridDB: по App ID {0} обложки не найдены.'
        sl_sg_searching = 'SteamGridDB: ищу «{0}»…'
        sl_sg_error = 'SteamGridDB: ошибка — {0}'
        sl_sg_notfound = 'SteamGridDB: ничего не найдено.'
        sl_sg_nogames = 'SteamGridDB: подходящих игр не найдено.'
        sl_sg_found_fetch = 'SteamGridDB: найдена «{0}», получаю варианты…'
        sl_sg_loading = 'SteamGridDB: загружаю {0}…'
        sl_sg_done = 'SteamGridDB: готово — {0} из 4. Игра: «{1}».'
        sl_sg_imgfail = 'SteamGridDB: изображения не загрузились.'
        sl_sg_alts = 'SteamGridDB: загружаю альтернативы для {0}…'
        sl_sg_noalts = 'SteamGridDB: альтернативы для этого типа не найдены.'
        sl_steam_loaded_alt = 'Steam: официальные обложки загружены. Для выбора альтернативы используется SteamGridDB.'
        bk_title = 'Резервная копия'
        bk_create_fail = 'Не удалось создать резервную копию:'
        sg_variants_fail = 'Не удалось получить варианты SteamGridDB: {0}'
        sg_pick_fail = 'Не удалось выбрать обложку: {0}'
        settings_open_fail = 'Не удалось открыть настройки: {0}'
        card_title = 'Карточка игры — {0}'
        card_name = 'Название'
        card_launch = 'Запуск'
        card_params = 'Параметры'
        card_params_tip = 'Параметры запуска'
        slot_vertical = '1. Вертикальная'
        slot_horizontal = '2. Горизонтальная'
        slot_hero = '3. Hero / фон'
        slot_logo = '4. Логотип'
        card_info = 'Steam — основной источник. Клик по любой миниатюре открывает варианты SteamGridDB только для этого типа, не переключая источник целиком.'
        card_save = 'Сохранить изменения'
        card_add = 'Добавить игру в библиотеку'
        card_cancel = 'Отменить'
        card_skip = 'Пропустить'
        badge_exe_manual = 'Исполняемый файл выбран вручную.'
        badge_opt_ok = 'Параметры относятся к выбранному EXE.'
        badge_opt_mismatch = 'Эти параметры относятся к {0}, а выбран {1}.'
        badge_title_ok = 'Название подтверждено по базе Steam/SteamGridDB.'
        badge_title_fail_src = 'Не удалось подтвердить название в выбранном источнике — проверьте его вручную.'
        badge_title_fail_pick = 'Не удалось подтвердить выбранное название — проверьте его вручную.'
        badge_title_fail_auto = 'Не удалось автоматически подтвердить название — проверьте его вручную.'
        badge_title_manual = 'Название изменено вручную и пока не подтверждено — выберите вариант из списка или найдите игру заново.'
        badge_exe_ok = 'Исполняемый файл определён уверенно.'
        badge_exe_multi = 'Найдено несколько исполняемых файлов — выбор не гарантирован, проверьте вручную.'
        badge_exe_none = 'Исполняемые файлы не найдены — выберите файл вручную.'
        badge_exe_steam = 'Исполняемый файл определён по данным Steam.'
        lo_no_hint = 'Steam не даёт отдельного описания для этих параметров.'
        st_lo_search = 'Steam: ищу параметры запуска…'
        st_lo_none = 'Steam: параметры запуска для этой игры не найдены.'
        st_lo_found = 'Steam: найдено вариантов запуска — {0}'
        st_name_needed_steam = 'Steam: введите название игры.'
        st_name_needed_sgdb = 'SteamGridDB: введите название игры.'
        st_searching_steam = 'Steam: ищу игру и официальные обложки…'
        st_searching_sgdb = 'SteamGridDB: ищу игру и обложки…'
        st_notfound_steam = 'Steam: игра по названию не найдена.'
        st_notfound_sgdb = 'SteamGridDB: игра по названию не найдена.'
        st_noid_steam = 'Steam: не удалось определить App ID.'
        st_noid_sgdb = 'SteamGridDB: не удалось определить SGDB ID.'
        st_src_error = '{0}: ошибка — {1}'
        st_exe_selected = 'Выбран EXE: {0}'
        st_no_exe = 'Исполняемые файлы не найдены.'
        st_pick_noid_steam = 'Steam: не удалось определить App ID выбранного варианта.'
        err_pick_noid_sgdb = 'Не удалось определить SGDB ID выбранного варианта.'
        st_searching_name_steam = 'Steam: ищу игру «{0}»…'
        st_game_notfound_steam = 'Steam: игра «{0}» не найдена.'
        st_no_variants = '{0}: вариантов для «{1}» не найдено.'
        st_id_digits_steam = 'App ID должен содержать только цифры.'
        st_id_digits_sgdb = 'SGDB ID должен содержать только цифры.'
        st_resolving_steam = 'Определяю Steam App ID и загружаю официальные ресурсы Steam…'
        st_resolving_sgdb = 'Определяю SGDB ID и загружаю ресурсы SteamGridDB…'
        st_covers_loaded = 'Текущие обложки загружены. Можно заменить их и сохранить изменения.'
        st_noid_hint_steam = 'Steam: App ID не определён. Откройте список у «Название» или введите App ID вручную.'
        st_noid_hint_sgdb = 'SteamGridDB: SGDB ID не определён. Откройте список у «Название».'
        st_enter_title = 'Введите название игры.'
        st_pick_exe = 'Выберите EXE или BAT-файл игры.'
        st_exe_gone = 'Выбранный EXE больше не существует.'
        st_exe_bat_gone = 'Выбранный EXE или BAT больше не существует.'
        st_no_workdir = 'Не удалось определить папку запуска выбранного файла.'
        hd_saving = 'Сохраняю изменения «{0}» в Steam…'
        hd_adding = 'Добавляю «{0}» в Steam…'
        st_done_saved_covers = 'Готово: изменения и обложки сохранены.'
        st_saved_no_covers = 'Изменения сохранены, но обложки не удалось записать.'
        st_done_saved = 'Готово: изменения сохранены.'
        st_done_added_covers = 'Готово: игра добавлена, обложки применены.'
        st_done_added_nocovers = 'Готово: игра добавлена, обложки не найдены.'
        st_error = 'Ошибка: {0}'
        hd_classify = 'Классификация игр…'
        hd_classify_n = 'Классификация: {0} ({1}/{2})'
        hd_auto_n = 'Авто: {0} ({1}/{2}) | карточек далее: {3}'
        hd_game_error = 'Ошибка «{0}»: {1}'
        hd_refine_n = 'Уточнение: {0} ({1}/{2})'
        hd_queue_left = ' · ещё в очереди: {0}'
        hd_stopped = 'Остановлено: ок {0}, авто {1}, пропуск {2}.'
        hd_finished = 'Готово: {0} из {1} (авто: {2}, пропуск: {3}).'
        hd_auto_batch_err = 'Ошибка автоматического пакетного добавления: {0}'
        hd_cancelling = 'Отмена… завершаю текущую игру.'
        hd_tick_one = 'Отметьте галочкой хотя бы одну игру.'
        hd_skip_existing = 'Пропуск уже добавленных игр: {0}. Продолжаю пакет…'
        hd_all_exist = 'Все выбранные игры уже есть в библиотеке Steam — добавлять нечего.'
        btn_cancel_batch = '✕  Отменить добавление'
        hd_autofill = 'Автозаполнение: {0} игр…'
        hd_cancelled = 'Отменено: ок {0} из {1} (автоматически: {2}, пропуск: {3}).'
        hd_autofill_done = 'Автозаполнение завершено: {0} из {1} (автоматически: {2}).'
        hd_autofill_err = 'Ошибка автозаполнения: {0}'
        hd_card_n = 'Карточка игры {0} из {1}: {2}'
        hd_batch_cancelled = 'Пакетное добавление отменено пользователем.'
        hd_skipped = 'Пропущена: {0}'
        hd_processing = 'Обработка выбрано: {0} игр.'
        hd_card_err = 'Ошибка открытия карточки: {0}'
    }
    en = @{
        hint_main = 'Double-click / Enter — open game card'
        panel_extra = 'Folder'
        panel_main = 'Folder'
        panel_free = '{0} [Free: {1} {2}]'
        unit_gb = 'GB'
        unit_mb = 'MB'
        unit_kb = 'KB'
        unit_b = 'B'
        path_prefix = 'Path: '
        browse = 'Browse...'
        search_cue = 'Search by folder name…'
        empty_main = 'Choose the main library folder with Non-Steam Games'
        empty_extra = 'Choose the additional folder with Non-Steam Games (used to temporarily move games to a fast SSD)'
        nothing_found = 'Nothing found for “{0}”'
        col_name = 'Name'
        col_size = 'Size'
        col_date = 'Date'
        col_lib = '✓'
        col_file = 'File'
        btn_move = 'Move game'
        btn_refresh = 'Refresh'
        batch_auto = 'Auto-fill cards'
        batch_auto_tip = 'If enabled: when adding several games at once, games whose name and exe are detected with confidence are added to the library automatically, without showing the card. The card opens only for games the program could not identify unambiguously.'
        btn_add_batch = '＋  Add selected games to library'
        btn_add_batch_n = '＋  Add selected games to library ({0})'
        tip_select_all = 'Tick all games in the list / clear all ticks'
        tip_lib_header = 'In Steam library (click to sort)'
        tip_row_check = 'Tick the game (for moving or batch adding)'
        tip_row_installed = 'This game is already in the Steam library'
        settings_title = 'Settings'
        settings_desc = 'Open program settings'
        pick_extra_folder = 'Choose folder'
        pick_main_folder = 'Choose folder'
        st_sizes_sort = 'Calculating folder sizes for sorting: {0} ({1} of {2})'
        st_move_first = 'First tick a game to move.'
        target_main = 'the target folder'
        target_extra = 'the target folder'
        msg_no_space = 'Not enough space on {0}!'
        err_junction = 'Failed to complete the move: {0}'
        move_title = 'MOVING'
        st_copy_progress = '{0}: {1} [Speed: {2} MB/s] [{3}%]'
        st_copy_done = '{0}: {1} [100%] — done'
        st_move_done = 'Done: moved {0} of {1} to {2}.'
        st_move_err = 'Move failed: {0}'
        st_refresh_start = 'Refreshing Steam library…'
        st_refresh_done = 'Steam library refreshed.'
        st_refresh_err = 'Refresh failed: {0}'
        st_sizes_checked = 'Calculating size of ticked games: {0} ({1} of {2})'
        st_checked_total = 'Ticked games: {0} — total size: {1} {2}'
        st_size_one = 'Size of “{0}”: {1} {2}'
        st_panel_sizes = 'Calculated size of all folders in the panel ({0}) — total: {1} {2}'
        st_removed = 'Removed from the list: {0}. Files on disk are untouched; the “Refresh” button brings the games back.'
        set_language = 'Language'
        set_steam_folder = 'Steam folder'
        set_profile = 'Profile'
        set_profile_hint = 'Choose the userdata profile the program will work with.'
        set_api_key = 'API key'
        key_valid = 'API key is valid.'
        key_invalid_default = 'API key is invalid or failed the check.'
        key_empty = 'No API key entered.'
        key_checking = 'Checking key…'
        key_hint_default = 'Needed to download game covers. You can get a free key at steamgriddb.com/profile/preferences.'
        key_new_key = ' New key: steamgriddb.com/profile/preferences.'
        sg_401 = 'The key is invalid or has been revoked (401).'
        sg_403 = 'Access denied (403): the key was revoked or the request was blocked by the service.'
        sg_429 = 'Too many requests to SteamGridDB (429). Try the check again later.'
        sg_server = 'SteamGridDB is temporarily unavailable (error {0}).'
        sg_other = 'Unexpected SteamGridDB response (code {0}).'
        sg_dns = 'Cannot find the steamgriddb.com server (DNS or internet problem).'
        sg_timeout = 'SteamGridDB did not respond within 10 seconds.'
        sg_tls = 'Secure connection (TLS) error with SteamGridDB.'
        sg_connect = 'Could not connect to SteamGridDB (connection dropped or no internet).'
        sg_noresp = 'No response from SteamGridDB: {0}'
        set_backup_section = 'shortcuts.vdf backups'
        set_backup_current = 'Current folder: {0}'
        set_create_backup = 'Create backup'
        set_restore = 'Restore'
        set_cancel = 'Cancel'
        set_save = 'Save'
        set_no_profiles = 'No Steam profiles found'
        set_profile_none = 'There are no userdata profiles in the selected folder.'
        set_profile_auto = 'Profile selected automatically. You can change it.'
        set_profile_chosen = 'Selected profile: {0}'
        set_profiles_fail = 'Could not read profiles'
        pick_steam_folder = 'Choose the Steam installation folder'
        pick_backup_folder = 'Choose the backup folder'
        no_backups = 'No backups yet'
        confirm_title = 'Restore'
        confirm_q = 'Restore shortcuts.vdf from the backup “{0}”?'
        confirm_note = 'Steam will be closed, the file replaced, and then Steam will be started again.'
        bk_no_source = 'The original shortcuts.vdf for this backup was not found.'
        bk_ready = 'Ready to restore.'
        bk_created = 'Backups created: {0}'
        bk_vdf_missing = 'shortcuts.vdf not found.'
        bk_closing = 'Closing Steam...'
        bk_no_steam_path = 'Could not determine the Steam path.'
        bk_restoring = 'Restoring the file...'
        bk_starting = 'Starting Steam...'
        bk_restored_ok = 'Restored and Steam restarted: {0}'
        bk_restored_nosteam = 'The file was restored, but Steam could not be started automatically.'
        bk_restore_err = 'Restore failed: {0}'
        set_path_empty = 'Specify the Steam installation folder.'
        set_path_missing = 'The specified Steam folder does not exist.'
        set_exe_missing = 'steam.exe was not found in the selected folder.'
        set_save_err = 'Could not save settings: {0}'
        vdf_eof = 'VDF file is truncated/corrupted (unexpected end of data)'
        vdf_eof_key = 'VDF file is truncated/corrupted (key name terminator not found)'
        vdf_eof_str = 'VDF file is truncated/corrupted (string value terminator not found)'
        vdf_eof_int = 'VDF file is truncated/corrupted (not enough bytes for int32)'
        vdf_bad_field = 'Unknown VDF field type: 0x{0} at position {1}'
        vdf_bad_type_key = 'Field ''{0}'' has an unexpected VDF type.'
        vdf_bad_type = 'Unknown VDF type: 0x{0}.'
        sc_not_found = 'The existing Steam shortcut was not found.'
        sc_file_missing = 'File shortcuts.vdf not found: {0}'
        sc_no_node = 'The ''shortcuts'' object was not found in shortcuts.vdf.'
        sc_target_gone = 'The shortcut being edited has disappeared from shortcuts.vdf.'
        sc_exists = 'The game “{0}” is already in the Steam library.'
        sc_userdata_missing = 'Folder ''{0}'' not found.'
        sc_node_corrupt = 'The ''shortcuts'' object was not found in shortcuts.vdf — the file is corrupted or has an unexpected format. Restore it from a manually created backup.'
        exe_dlg_title = 'Select launch file — {0}'
        exe_dlg_hint = 'Several executables were found. Choose the right one:'
        exe_dlg_col = 'File path'
        exe_dlg_ok = 'Confirm'
        exe_outside = 'Choose an executable only from the game folder or its subfolders.'
        exe_outside_title = 'Invalid path'
        ofd_title = 'Select the game''s EXE or BAT file'
        ofd_filter = 'Executable files (*.exe;*.bat)|*.exe;*.bat|EXE (*.exe)|*.exe|BAT (*.bat)|*.bat'
        reason_title_unconfirmed = 'The title could not be confirmed automatically.'
        reason_exe_missing = 'Executable not found.'
        reason_multi_exe = 'Several executables were found — the choice is not guaranteed.'
        reason_shortcut_fail = 'Failed to create the Steam shortcut.'
        reason_save_shortcut = 'Failed to save the Steam shortcut.'
        sgdb_chooser_hint = 'Choose an option. The most popular ones are shown first. Thumbnails load in the background.'
        src_tip_steam = 'Source: Steam'
        src_tip_sgdb = 'Source: SteamGridDB'
        sl_no_appid = 'App ID not specified — official Steam covers are unavailable.'
        sl_steam_fetch = 'Fetching official Steam assets for App ID {0}…'
        sl_steam_found = 'Steam: assets found — {0} of 4.'
        covlang_tip = 'Steam cover region: {0}. Click to choose another one.'
        covlang_no_appid = 'Cover region: the game App ID is required first.'
        covlang_checking = 'Checking available cover regions…'
        covlang_unavailable = 'Could not determine the available cover regions for this game.'
        covlang_only_one = 'Only one cover region is available for this game: {0}.'
        covlang_pick = 'Choose the cover region.'
        covlang_loading = 'Loading covers for region "{0}"…'
        covlang_done = 'Cover region: {0}. Assets updated: {1}.'
        covlang_fail = 'Could not load covers for region "{0}".'
        covlang_all_sgdb = 'All covers were picked from SteamGridDB — nothing to change for the Steam region.'
        sl_steam_fail = 'Steam: failed to fetch assets ({0}).'
        sl_sg_nokey = 'SteamGridDB: API key is not set.'
        sl_sg_keysaved = 'SteamGridDB: API key saved.'
        sl_sg_need_name = 'SteamGridDB: enter a title or App ID.'
        sl_sg_variants = 'SteamGridDB: fetching options for “{0}”…'
        sl_sg_nocovers = 'SteamGridDB: no covers available for “{0}”.'
        sl_sg_by_id = 'SteamGridDB: searching by App ID {0}…'
        sl_sg_id_none = 'SteamGridDB: no covers found for App ID {0}.'
        sl_sg_searching = 'SteamGridDB: searching for “{0}”…'
        sl_sg_error = 'SteamGridDB: error — {0}'
        sl_sg_notfound = 'SteamGridDB: nothing found.'
        sl_sg_nogames = 'SteamGridDB: no matching games found.'
        sl_sg_found_fetch = 'SteamGridDB: found “{0}”, fetching options…'
        sl_sg_loading = 'SteamGridDB: loading {0}…'
        sl_sg_done = 'SteamGridDB: done — {0} of 4. Game: “{1}”.'
        sl_sg_imgfail = 'SteamGridDB: images failed to load.'
        sl_sg_alts = 'SteamGridDB: loading alternatives for {0}…'
        sl_sg_noalts = 'SteamGridDB: no alternatives found for this type.'
        sl_steam_loaded_alt = 'Steam: official covers loaded. SteamGridDB is used to pick alternatives.'
        bk_title = 'Backup'
        bk_create_fail = 'Could not create a backup:'
        sg_variants_fail = 'Could not get SteamGridDB options: {0}'
        sg_pick_fail = 'Could not select the cover: {0}'
        settings_open_fail = 'Could not open settings: {0}'
        card_title = 'Game card — {0}'
        card_name = 'Name'
        card_launch = 'Launch'
        card_params = 'Parameters'
        card_params_tip = 'Launch parameters'
        slot_vertical = '1. Vertical'
        slot_horizontal = '2. Horizontal'
        slot_hero = '3. Hero / background'
        slot_logo = '4. Logo'
        card_info = 'Steam is the primary source. Clicking any thumbnail opens SteamGridDB options for that type only, without switching the whole source.'
        card_save = 'Save changes'
        card_add = 'Add game to library'
        card_cancel = 'Cancel'
        card_skip = 'Skip'
        badge_exe_manual = 'Executable selected manually.'
        badge_opt_ok = 'The parameters belong to the selected EXE.'
        badge_opt_mismatch = 'These parameters belong to {0}, but {1} is selected.'
        badge_title_ok = 'Title confirmed against the Steam/SteamGridDB database.'
        badge_title_fail_src = 'Could not confirm the title in the selected source — please check it manually.'
        badge_title_fail_pick = 'Could not confirm the selected title — please check it manually.'
        badge_title_fail_auto = 'Could not confirm the title automatically — please check it manually.'
        badge_title_manual = 'The title was changed manually and is not confirmed yet — pick an option from the list or search for the game again.'
        badge_exe_ok = 'Executable detected with confidence.'
        badge_exe_multi = 'Several executables were found — the choice is not guaranteed, please check manually.'
        badge_exe_none = 'No executables found — choose the file manually.'
        badge_exe_steam = 'Executable determined from Steam data.'
        lo_no_hint = 'Steam gives no separate description for these parameters.'
        st_lo_search = 'Steam: looking up launch parameters…'
        st_lo_none = 'Steam: no launch parameters found for this game.'
        st_lo_found = 'Steam: launch options found — {0}'
        st_name_needed_steam = 'Steam: enter the game title.'
        st_name_needed_sgdb = 'SteamGridDB: enter the game title.'
        st_searching_steam = 'Steam: searching for the game and official covers…'
        st_searching_sgdb = 'SteamGridDB: searching for the game and covers…'
        st_notfound_steam = 'Steam: no game found for this title.'
        st_notfound_sgdb = 'SteamGridDB: no game found for this title.'
        st_noid_steam = 'Steam: could not determine the App ID.'
        st_noid_sgdb = 'SteamGridDB: could not determine the SGDB ID.'
        st_src_error = '{0}: error — {1}'
        st_exe_selected = 'Selected EXE: {0}'
        st_no_exe = 'No executables found.'
        st_pick_noid_steam = 'Steam: could not determine the App ID of the selected option.'
        err_pick_noid_sgdb = 'Could not determine the SGDB ID of the selected option.'
        st_searching_name_steam = 'Steam: searching for “{0}”…'
        st_game_notfound_steam = 'Steam: game “{0}” not found.'
        st_no_variants = '{0}: no options found for “{1}”.'
        st_id_digits_steam = 'App ID must contain digits only.'
        st_id_digits_sgdb = 'SGDB ID must contain digits only.'
        st_resolving_steam = 'Determining the Steam App ID and loading official Steam assets…'
        st_resolving_sgdb = 'Determining the SGDB ID and loading SteamGridDB assets…'
        st_covers_loaded = 'Current covers loaded. You can replace them and save the changes.'
        st_noid_hint_steam = 'Steam: App ID not determined. Open the list next to “Name” or enter the App ID manually.'
        st_noid_hint_sgdb = 'SteamGridDB: SGDB ID not determined. Open the list next to “Name”.'
        st_enter_title = 'Enter the game title.'
        st_pick_exe = 'Choose the game''s EXE or BAT file.'
        st_exe_gone = 'The selected EXE no longer exists.'
        st_exe_bat_gone = 'The selected EXE or BAT no longer exists.'
        st_no_workdir = 'Could not determine the working folder of the selected file.'
        hd_saving = 'Saving changes to “{0}” in Steam…'
        hd_adding = 'Adding “{0}” to Steam…'
        st_done_saved_covers = 'Done: changes and covers saved.'
        st_saved_no_covers = 'Changes saved, but the covers could not be written.'
        st_done_saved = 'Done: changes saved.'
        st_done_added_covers = 'Done: game added, covers applied.'
        st_done_added_nocovers = 'Done: game added, no covers found.'
        st_error = 'Error: {0}'
        hd_classify = 'Classifying games…'
        hd_classify_n = 'Classifying: {0} ({1}/{2})'
        hd_auto_n = 'Auto: {0} ({1}/{2}) | cards next: {3}'
        hd_game_error = 'Error “{0}”: {1}'
        hd_refine_n = 'Refining: {0} ({1}/{2})'
        hd_queue_left = ' · {0} more in queue'
        hd_stopped = 'Stopped: OK {0}, auto {1}, skipped {2}.'
        hd_finished = 'Done: {0} of {1} (auto: {2}, skipped: {3}).'
        hd_auto_batch_err = 'Automatic batch add failed: {0}'
        hd_cancelling = 'Cancelling… finishing the current game.'
        hd_tick_one = 'Tick at least one game.'
        hd_skip_existing = 'Skipping games already added: {0}. Continuing the batch…'
        hd_all_exist = 'All selected games are already in the Steam library — nothing to add.'
        btn_cancel_batch = '✕  Cancel adding'
        hd_autofill = 'Auto-fill: {0} games…'
        hd_cancelled = 'Cancelled: OK {0} of {1} (automatic: {2}, skipped: {3}).'
        hd_autofill_done = 'Auto-fill finished: {0} of {1} (automatic: {2}).'
        hd_autofill_err = 'Auto-fill failed: {0}'
        hd_card_n = 'Game card {0} of {1}: {2}'
        hd_batch_cancelled = 'Batch adding was cancelled by the user.'
        hd_skipped = 'Skipped: {0}'
        hd_processing = 'Processing selected: {0} games.'
        hd_card_err = 'Could not open the card: {0}'
    }
    zh = @{
        hint_main = '双击 / 回车 — 打开游戏卡片'
        panel_extra = '文件夹'
        panel_main = '文件夹'
        panel_free = '{0} [可用空间：{1} {2}]'
        unit_gb = 'GB'
        unit_mb = 'MB'
        unit_kb = 'KB'
        unit_b = 'B'
        path_prefix = '路径：'
        browse = '浏览...'
        search_cue = '按文件夹名称搜索…'
        empty_main = '请选择包含非 Steam 游戏的主库文件夹'
        empty_extra = '请选择包含非 Steam 游戏的附加文件夹（用于将游戏临时移动到高速 SSD）'
        nothing_found = '未找到与“{0}”匹配的内容'
        col_name = '名称'
        col_size = '大小'
        col_date = '日期'
        col_lib = '✓'
        col_file = '文件'
        btn_move = '移动游戏'
        btn_refresh = '刷新'
        batch_auto = '自动填写卡片'
        batch_auto_tip = '启用后：一次添加多个游戏时，名称和 exe 能被明确识别的游戏会自动加入库中，不再显示卡片。仅对程序无法明确识别的游戏才会打开卡片。'
        btn_add_batch = '＋  将所选游戏添加到库'
        btn_add_batch_n = '＋  将所选游戏添加到库（{0}）'
        tip_select_all = '勾选列表中的所有游戏 / 取消全部勾选'
        tip_lib_header = '是否在 Steam 库中（点击排序）'
        tip_row_check = '勾选游戏（用于移动或批量添加）'
        tip_row_installed = '该游戏已在 Steam 库中'
        settings_title = '设置'
        settings_desc = '打开程序设置'
        pick_extra_folder = '选择附加文件夹'
        pick_main_folder = '选择主文件夹'
        st_sizes_sort = '正在计算文件夹大小以便排序：{0}（{1}/{2}）'
        st_move_first = '请先勾选要移动的游戏。'
        target_main = '主文件夹'
        target_extra = '附加文件夹'
        msg_no_space = '{0} 上的可用空间不足！'
        err_junction = '无法删除 junction：{0}'
        move_title = '移动中'
        st_copy_progress = '{0}：{1} [速度：{2} MB/s] [{3}%]'
        st_copy_done = '{0}：{1} [100%] — 完成'
        st_move_done = '完成：已移动 {0}/{1} 个游戏到{2}。'
        st_move_err = '移动失败：{0}'
        st_refresh_start = '正在刷新 Steam 库…'
        st_refresh_done = 'Steam 库已刷新。'
        st_refresh_err = '刷新失败：{0}'
        st_sizes_checked = '正在计算已勾选游戏的大小：{0}（{1}/{2}）'
        st_checked_total = '已勾选游戏：{0} — 总大小：{1} {2}'
        st_size_one = '“{0}”的大小：{1} {2}'
        st_panel_sizes = '已计算面板（{0}）中所有文件夹的大小 — 合计：{1} {2}'
        st_removed = '已从列表中移除：{0}。磁盘上的文件未受影响；点击“刷新”按钮即可恢复这些游戏。'
        set_language = '语言'
        set_steam_folder = 'Steam 文件夹'
        set_profile = '配置文件'
        set_profile_hint = '选择程序要使用的 userdata 配置文件。'
        set_api_key = 'API 密钥'
        key_valid = 'API 密钥有效。'
        key_invalid_default = 'API 密钥无效或验证失败。'
        key_empty = '未输入 API 密钥。'
        key_checking = '正在验证密钥…'
        key_hint_default = '用于下载游戏封面。可在 steamgriddb.com/profile/preferences 免费获取密钥。'
        key_new_key = ' 获取新密钥：steamgriddb.com/profile/preferences。'
        sg_401 = '密钥无效或已被吊销（401）。'
        sg_403 = '访问被拒绝（403）：密钥已被吊销，或请求被该服务拦截。'
        sg_429 = '向 SteamGridDB 发送的请求过多（429）。请稍后重新验证。'
        sg_server = 'SteamGridDB 暂时不可用（错误 {0}）。'
        sg_other = 'SteamGridDB 返回了意外的响应（代码 {0}）。'
        sg_dns = '无法找到 steamgriddb.com 服务器（DNS 或网络问题）。'
        sg_timeout = 'SteamGridDB 在 10 秒内未响应。'
        sg_tls = '与 SteamGridDB 的安全连接（TLS）出错。'
        sg_connect = '无法连接到 SteamGridDB（连接中断或未联网）。'
        sg_noresp = 'SteamGridDB 无响应：{0}'
        set_backup_section = 'shortcuts.vdf 备份'
        set_backup_current = '当前文件夹：{0}'
        set_create_backup = '创建备份'
        set_restore = '恢复'
        set_cancel = '取消'
        set_save = '保存'
        set_no_profiles = '未找到 Steam 配置文件'
        set_profile_none = '所选文件夹中没有 userdata 配置文件。'
        set_profile_auto = '已自动选择配置文件，您可以更改。'
        set_profile_chosen = '已选择的配置文件：{0}'
        set_profiles_fail = '无法读取配置文件'
        pick_steam_folder = '选择 Steam 安装文件夹'
        pick_backup_folder = '选择备份文件夹'
        no_backups = '暂无备份'
        confirm_title = '恢复'
        confirm_q = '要从备份“{0}”恢复 shortcuts.vdf 吗？'
        confirm_note = '将关闭 Steam，替换该文件，然后重新启动 Steam。'
        bk_no_source = '未找到此备份对应的原始 shortcuts.vdf。'
        bk_ready = '可以恢复。'
        bk_created = '已创建备份：{0}'
        bk_vdf_missing = '未找到 shortcuts.vdf。'
        bk_closing = '正在关闭 Steam...'
        bk_no_steam_path = '无法确定 Steam 路径。'
        bk_restoring = '正在恢复文件...'
        bk_starting = '正在启动 Steam...'
        bk_restored_ok = '已恢复并重启 Steam：{0}'
        bk_restored_nosteam = '文件已恢复，但无法自动启动 Steam。'
        bk_restore_err = '恢复失败：{0}'
        set_path_empty = '请指定 Steam 安装文件夹。'
        set_path_missing = '指定的 Steam 文件夹不存在。'
        set_exe_missing = '在所选文件夹中未找到 steam.exe。'
        set_save_err = '无法保存设置：{0}'
        vdf_eof = 'VDF 文件被截断或已损坏（数据意外结束）'
        vdf_eof_key = 'VDF 文件被截断或已损坏（未找到键名终止符）'
        vdf_eof_str = 'VDF 文件被截断或已损坏（未找到字符串值终止符）'
        vdf_eof_int = 'VDF 文件被截断或已损坏（int32 所需字节数不足）'
        vdf_bad_field = '未知的 VDF 字段类型：0x{0}（位置 {1}）'
        vdf_bad_type_key = '字段“{0}”的 VDF 类型异常。'
        vdf_bad_type = '未知的 VDF 类型：0x{0}。'
        sc_not_found = '未找到已有的 Steam 快捷方式。'
        sc_file_missing = '未找到文件 shortcuts.vdf：{0}'
        sc_no_node = '在 shortcuts.vdf 中未找到“shortcuts”对象。'
        sc_target_gone = '正在编辑的快捷方式已从 shortcuts.vdf 中消失。'
        sc_exists = '游戏“{0}”已在 Steam 库中。'
        sc_userdata_missing = '未找到文件夹“{0}”。'
        sc_node_corrupt = '在 shortcuts.vdf 中未找到“shortcuts”对象 — 文件已损坏或格式异常。请从手动创建的备份中恢复。'
        exe_dlg_title = '选择启动文件 — {0}'
        exe_dlg_hint = '找到多个可执行文件，请选择正确的一个：'
        exe_dlg_col = '文件路径'
        exe_dlg_ok = '确认'
        exe_outside = '只能从游戏文件夹或其子文件夹中选择可执行文件。'
        exe_outside_title = '路径无效'
        ofd_title = '选择游戏的 EXE 或 BAT 文件'
        ofd_filter = '可执行文件 (*.exe;*.bat)|*.exe;*.bat|EXE (*.exe)|*.exe|BAT (*.bat)|*.bat'
        reason_title_unconfirmed = '无法自动确认游戏名称。'
        reason_exe_missing = '未找到可执行文件。'
        reason_multi_exe = '找到多个可执行文件 — 无法保证选择正确。'
        reason_shortcut_fail = '创建 Steam 快捷方式失败。'
        reason_save_shortcut = '保存 Steam 快捷方式失败。'
        sgdb_chooser_hint = '请选择一个选项，最受欢迎的排在前面。缩略图将在后台加载。'
        src_tip_steam = '来源：Steam'
        src_tip_sgdb = '来源：SteamGridDB'
        sl_no_appid = '未指定 App ID — 无法使用 Steam 官方封面。'
        sl_steam_fetch = '正在获取 App ID {0} 的 Steam 官方素材…'
        sl_steam_found = 'Steam：已找到素材 — {0}/4。'
        covlang_tip = 'Steam 封面区域：{0}。点击可选择其他区域。'
        covlang_no_appid = '封面区域：需要先填写游戏的 App ID。'
        covlang_checking = '正在检查可用的封面区域…'
        covlang_unavailable = '无法确定该游戏可用的封面区域。'
        covlang_only_one = '该游戏只有一个可用的封面区域：{0}。'
        covlang_pick = '请选择封面区域。'
        covlang_loading = '正在加载“{0}”区域的封面…'
        covlang_done = '封面区域：{0}。已更新素材：{1}。'
        covlang_fail = '无法加载“{0}”区域的封面。'
        covlang_all_sgdb = '所有封面均选自 SteamGridDB — 无需更改 Steam 封面区域。'
        sl_steam_fail = 'Steam：获取素材失败（{0}）。'
        sl_sg_nokey = 'SteamGridDB：未设置 API 密钥。'
        sl_sg_keysaved = 'SteamGridDB：API 密钥已保存。'
        sl_sg_need_name = 'SteamGridDB：请输入名称或 App ID。'
        sl_sg_variants = 'SteamGridDB：正在获取“{0}”的可选项…'
        sl_sg_nocovers = 'SteamGridDB：没有“{0}”的可用封面。'
        sl_sg_by_id = 'SteamGridDB：正在按 App ID {0} 搜索…'
        sl_sg_id_none = 'SteamGridDB：未找到 App ID {0} 的封面。'
        sl_sg_searching = 'SteamGridDB：正在搜索“{0}”…'
        sl_sg_error = 'SteamGridDB：出错 — {0}'
        sl_sg_notfound = 'SteamGridDB：未找到任何内容。'
        sl_sg_nogames = 'SteamGridDB：未找到匹配的游戏。'
        sl_sg_found_fetch = 'SteamGridDB：已找到“{0}”，正在获取可选项…'
        sl_sg_loading = 'SteamGridDB：正在加载 {0}…'
        sl_sg_done = 'SteamGridDB：完成 — {0}/4。游戏：“{1}”。'
        sl_sg_imgfail = 'SteamGridDB：图片加载失败。'
        sl_sg_alts = 'SteamGridDB：正在加载 {0} 的备选项…'
        sl_sg_noalts = 'SteamGridDB：未找到该类型的备选项。'
        sl_steam_loaded_alt = 'Steam：已加载官方封面。可使用 SteamGridDB 选择备选封面。'
        bk_title = '备份'
        bk_create_fail = '无法创建备份：'
        sg_variants_fail = '无法获取 SteamGridDB 可选项：{0}'
        sg_pick_fail = '无法选择该封面：{0}'
        settings_open_fail = '无法打开设置：{0}'
        card_title = '游戏卡片 — {0}'
        card_name = '名称'
        card_launch = '启动'
        card_params = '参数'
        card_params_tip = '启动参数'
        slot_vertical = '1. 竖版'
        slot_horizontal = '2. 横版'
        slot_hero = '3. Hero / 背景'
        slot_logo = '4. Logo'
        card_info = 'Steam 为主要来源。点击任意缩略图只会打开该类型的 SteamGridDB 可选项，而不会切换整个来源。'
        card_save = '保存更改'
        card_add = '添加游戏到库'
        card_cancel = '取消'
        card_skip = '跳过'
        badge_exe_manual = '已手动选择可执行文件。'
        badge_opt_ok = '这些参数属于所选的 EXE。'
        badge_opt_mismatch = '这些参数属于 {0}，但当前选择的是 {1}。'
        badge_title_ok = '名称已通过 Steam/SteamGridDB 数据库确认。'
        badge_title_fail_src = '无法在所选来源中确认名称 — 请手动检查。'
        badge_title_fail_pick = '无法确认所选名称 — 请手动检查。'
        badge_title_fail_auto = '无法自动确认名称 — 请手动检查。'
        badge_title_manual = '名称已被手动修改，尚未确认 — 请从列表中选择一项，或重新搜索该游戏。'
        badge_exe_ok = '已明确识别出可执行文件。'
        badge_exe_multi = '找到多个可执行文件 — 无法保证选择正确，请手动检查。'
        badge_exe_none = '未找到可执行文件 — 请手动选择文件。'
        badge_exe_steam = '可执行文件已根据 Steam 数据确定。'
        lo_no_hint = 'Steam 未提供这些参数的单独说明。'
        st_lo_search = 'Steam：正在查找启动参数…'
        st_lo_none = 'Steam：未找到该游戏的启动参数。'
        st_lo_found = 'Steam：已找到启动选项 — {0}'
        st_name_needed_steam = 'Steam：请输入游戏名称。'
        st_name_needed_sgdb = 'SteamGridDB：请输入游戏名称。'
        st_searching_steam = 'Steam：正在搜索游戏和官方封面…'
        st_searching_sgdb = 'SteamGridDB：正在搜索游戏和封面…'
        st_notfound_steam = 'Steam：未找到与该名称匹配的游戏。'
        st_notfound_sgdb = 'SteamGridDB：未找到与该名称匹配的游戏。'
        st_noid_steam = 'Steam：无法确定 App ID。'
        st_noid_sgdb = 'SteamGridDB：无法确定 SGDB ID。'
        st_src_error = '{0}：出错 — {1}'
        st_exe_selected = '已选择的 EXE：{0}'
        st_no_exe = '未找到可执行文件。'
        st_pick_noid_steam = 'Steam：无法确定所选选项的 App ID。'
        err_pick_noid_sgdb = '无法确定所选选项的 SGDB ID。'
        st_searching_name_steam = 'Steam：正在搜索“{0}”…'
        st_game_notfound_steam = 'Steam：未找到游戏“{0}”。'
        st_no_variants = '{0}：未找到“{1}”的可选项。'
        st_id_digits_steam = 'App ID 只能包含数字。'
        st_id_digits_sgdb = 'SGDB ID 只能包含数字。'
        st_resolving_steam = '正在确定 Steam App ID 并加载 Steam 官方素材…'
        st_resolving_sgdb = '正在确定 SGDB ID 并加载 SteamGridDB 素材…'
        st_covers_loaded = '当前封面已加载。您可以替换它们并保存更改。'
        st_noid_hint_steam = 'Steam：未确定 App ID。请打开“名称”旁边的列表，或手动输入 App ID。'
        st_noid_hint_sgdb = 'SteamGridDB：未确定 SGDB ID。请打开“名称”旁边的列表。'
        st_enter_title = '请输入游戏名称。'
        st_pick_exe = '请选择游戏的 EXE 或 BAT 文件。'
        st_exe_gone = '所选的 EXE 已不存在。'
        st_exe_bat_gone = '所选的 EXE 或 BAT 已不存在。'
        st_no_workdir = '无法确定所选文件的工作文件夹。'
        hd_saving = '正在将对“{0}”的更改保存到 Steam…'
        hd_adding = '正在将“{0}”添加到 Steam…'
        st_done_saved_covers = '完成：更改和封面已保存。'
        st_saved_no_covers = '更改已保存，但封面无法写入。'
        st_done_saved = '完成：更改已保存。'
        st_done_added_covers = '完成：游戏已添加，封面已应用。'
        st_done_added_nocovers = '完成：游戏已添加，未找到封面。'
        st_error = '错误：{0}'
        hd_classify = '正在对游戏分类…'
        hd_classify_n = '正在分类：{0}（{1}/{2}）'
        hd_auto_n = '自动：{0}（{1}/{2}）| 后续卡片：{3}'
        hd_game_error = '“{0}”出错：{1}'
        hd_refine_n = '正在精确匹配：{0}（{1}/{2}）'
        hd_queue_left = ' · 队列中还有 {0} 个'
        hd_stopped = '已停止：成功 {0}，自动 {1}，跳过 {2}。'
        hd_finished = '完成：{0}/{1}（自动：{2}，跳过：{3}）。'
        hd_auto_batch_err = '自动批量添加失败：{0}'
        hd_cancelling = '正在取消… 正在完成当前游戏。'
        hd_tick_one = '请至少勾选一个游戏。'
        hd_skip_existing = '跳过已添加的游戏：{0}。继续批量处理…'
        hd_all_exist = '所选游戏均已在 Steam 库中 — 没有可添加的内容。'
        btn_cancel_batch = '✕  取消添加'
        hd_autofill = '自动填写：{0} 个游戏…'
        hd_cancelled = '已取消：成功 {0}/{1}（自动：{2}，跳过：{3}）。'
        hd_autofill_done = '自动填写完成：{0}/{1}（自动：{2}）。'
        hd_autofill_err = '自动填写失败：{0}'
        hd_card_n = '游戏卡片 {0}/{1}：{2}'
        hd_batch_cancelled = '批量添加已被用户取消。'
        hd_skipped = '已跳过：{0}'
        hd_processing = '正在处理所选游戏：{0} 个。'
        hd_card_err = '无法打开卡片：{0}'
    }
    es = @{
        hint_main = 'Doble clic / Intro — abrir la ficha del juego'
        panel_extra = 'Carpeta'
        panel_main = 'Carpeta'
        panel_free = '{0} [Libre: {1} {2}]'
        unit_gb = 'GB'
        unit_mb = 'MB'
        unit_kb = 'KB'
        unit_b = 'B'
        path_prefix = 'Ruta: '
        browse = 'Examinar...'
        search_cue = 'Buscar por nombre de carpeta…'
        empty_main = 'Elige la carpeta principal de la biblioteca con juegos que no son de Steam'
        empty_extra = 'Elige la carpeta adicional con juegos que no son de Steam (se usa para mover juegos temporalmente a un SSD rápido)'
        nothing_found = 'No se encontró nada para “{0}”'
        col_name = 'Nombre'
        col_size = 'Tamaño'
        col_date = 'Fecha'
        col_lib = '✓'
        col_file = 'Archivo'
        btn_move = 'Mover juego'
        btn_refresh = 'Actualizar'
        batch_auto = 'Rellenar fichas automáticamente'
        batch_auto_tip = 'Si está activado: al añadir varios juegos a la vez, los juegos cuyo nombre y exe se detectan con seguridad se añaden a la biblioteca automáticamente, sin mostrar la ficha. La ficha solo se abre para los juegos que el programa no pudo identificar sin ambigüedad.'
        btn_add_batch = '＋  Añadir juegos seleccionados a la biblioteca'
        btn_add_batch_n = '＋  Añadir juegos seleccionados a la biblioteca ({0})'
        tip_select_all = 'Marcar todos los juegos de la lista / quitar todas las marcas'
        tip_lib_header = 'En la biblioteca de Steam (clic para ordenar)'
        tip_row_check = 'Marcar el juego (para moverlo o añadirlo en lote)'
        tip_row_installed = 'Este juego ya está en la biblioteca de Steam'
        settings_title = 'Ajustes'
        settings_desc = 'Abrir los ajustes del programa'
        pick_extra_folder = 'Elige la carpeta adicional'
        pick_main_folder = 'Elige la carpeta principal'
        st_sizes_sort = 'Calculando el tamaño de las carpetas para ordenar: {0} ({1} de {2})'
        st_move_first = 'Primero marca un juego para moverlo.'
        target_main = 'la carpeta principal'
        target_extra = 'la carpeta adicional'
        msg_no_space = '¡No hay espacio suficiente en {0}!'
        err_junction = 'No se pudo eliminar el punto de unión (junction): {0}'
        move_title = 'MOVIENDO'
        st_copy_progress = '{0}: {1} [Velocidad: {2} MB/s] [{3}%]'
        st_copy_done = '{0}: {1} [100%] — completado'
        st_move_done = 'Listo: movidos {0} de {1} a {2}.'
        st_move_err = 'Error al mover: {0}'
        st_refresh_start = 'Actualizando la biblioteca de Steam…'
        st_refresh_done = 'Biblioteca de Steam actualizada.'
        st_refresh_err = 'Error al actualizar: {0}'
        st_sizes_checked = 'Calculando el tamaño de los juegos marcados: {0} ({1} de {2})'
        st_checked_total = 'Juegos marcados: {0} — tamaño total: {1} {2}'
        st_size_one = 'Tamaño de “{0}”: {1} {2}'
        st_panel_sizes = 'Tamaño calculado de todas las carpetas del panel ({0}) — total: {1} {2}'
        st_removed = 'Quitados de la lista: {0}. Los archivos del disco no se han tocado; el botón “Actualizar” recupera los juegos.'
        set_language = 'Idioma'
        set_steam_folder = 'Carpeta de Steam'
        set_profile = 'Perfil'
        set_profile_hint = 'Elige el perfil de userdata con el que trabajará el programa.'
        set_api_key = 'Clave de API'
        key_valid = 'La clave de API es válida.'
        key_invalid_default = 'La clave de API no es válida o no superó la comprobación.'
        key_empty = 'No se ha introducido ninguna clave de API.'
        key_checking = 'Comprobando la clave…'
        key_hint_default = 'Necesaria para descargar portadas de juegos. Puedes obtener una clave gratuita en steamgriddb.com/profile/preferences.'
        key_new_key = ' Nueva clave: steamgriddb.com/profile/preferences.'
        sg_401 = 'La clave no es válida o ha sido revocada (401).'
        sg_403 = 'Acceso denegado (403): la clave fue revocada o el servicio bloqueó la solicitud.'
        sg_429 = 'Demasiadas solicitudes a SteamGridDB (429). Vuelve a intentar la comprobación más tarde.'
        sg_server = 'SteamGridDB no está disponible temporalmente (error {0}).'
        sg_other = 'Respuesta inesperada de SteamGridDB (código {0}).'
        sg_dns = 'No se encuentra el servidor steamgriddb.com (problema de DNS o de internet).'
        sg_timeout = 'SteamGridDB no respondió en 10 segundos.'
        sg_tls = 'Error de conexión segura (TLS) con SteamGridDB.'
        sg_connect = 'No se pudo conectar con SteamGridDB (conexión interrumpida o sin internet).'
        sg_noresp = 'Sin respuesta de SteamGridDB: {0}'
        set_backup_section = 'Copias de seguridad de shortcuts.vdf'
        set_backup_current = 'Carpeta actual: {0}'
        set_create_backup = 'Crear copia de seguridad'
        set_restore = 'Restaurar'
        set_cancel = 'Cancelar'
        set_save = 'Guardar'
        set_no_profiles = 'No se encontraron perfiles de Steam'
        set_profile_none = 'No hay perfiles de userdata en la carpeta seleccionada.'
        set_profile_auto = 'Perfil seleccionado automáticamente. Puedes cambiarlo.'
        set_profile_chosen = 'Perfil seleccionado: {0}'
        set_profiles_fail = 'No se pudieron leer los perfiles'
        pick_steam_folder = 'Elige la carpeta de instalación de Steam'
        pick_backup_folder = 'Elige la carpeta de copias de seguridad'
        no_backups = 'Aún no hay copias de seguridad'
        confirm_title = 'Restaurar'
        confirm_q = '¿Restaurar shortcuts.vdf desde la copia “{0}”?'
        confirm_note = 'Steam se cerrará, se reemplazará el archivo y después Steam se iniciará de nuevo.'
        bk_no_source = 'No se encontró el shortcuts.vdf original de esta copia.'
        bk_ready = 'Listo para restaurar.'
        bk_created = 'Copias de seguridad creadas: {0}'
        bk_vdf_missing = 'No se encontró shortcuts.vdf.'
        bk_closing = 'Cerrando Steam...'
        bk_no_steam_path = 'No se pudo determinar la ruta de Steam.'
        bk_restoring = 'Restaurando el archivo...'
        bk_starting = 'Iniciando Steam...'
        bk_restored_ok = 'Restaurado y Steam reiniciado: {0}'
        bk_restored_nosteam = 'El archivo se restauró, pero no se pudo iniciar Steam automáticamente.'
        bk_restore_err = 'Error al restaurar: {0}'
        set_path_empty = 'Indica la carpeta de instalación de Steam.'
        set_path_missing = 'La carpeta de Steam indicada no existe.'
        set_exe_missing = 'No se encontró steam.exe en la carpeta seleccionada.'
        set_save_err = 'No se pudieron guardar los ajustes: {0}'
        vdf_eof = 'El archivo VDF está truncado o dañado (fin de datos inesperado)'
        vdf_eof_key = 'El archivo VDF está truncado o dañado (no se encontró el terminador del nombre de clave)'
        vdf_eof_str = 'El archivo VDF está truncado o dañado (no se encontró el terminador del valor de cadena)'
        vdf_eof_int = 'El archivo VDF está truncado o dañado (no hay bytes suficientes para int32)'
        vdf_bad_field = 'Tipo de campo VDF desconocido: 0x{0} en la posición {1}'
        vdf_bad_type_key = 'El campo “{0}” tiene un tipo VDF inesperado.'
        vdf_bad_type = 'Tipo VDF desconocido: 0x{0}.'
        sc_not_found = 'No se encontró el acceso directo de Steam existente.'
        sc_file_missing = 'No se encontró el archivo shortcuts.vdf: {0}'
        sc_no_node = 'No se encontró el objeto “shortcuts” en shortcuts.vdf.'
        sc_target_gone = 'El acceso directo que se estaba editando ha desaparecido de shortcuts.vdf.'
        sc_exists = 'El juego “{0}” ya está en la biblioteca de Steam.'
        sc_userdata_missing = 'No se encontró la carpeta “{0}”.'
        sc_node_corrupt = 'No se encontró el objeto “shortcuts” en shortcuts.vdf — el archivo está dañado o tiene un formato inesperado. Restáuralo desde una copia de seguridad creada manualmente.'
        exe_dlg_title = 'Selecciona el archivo de inicio — {0}'
        exe_dlg_hint = 'Se encontraron varios ejecutables. Elige el correcto:'
        exe_dlg_col = 'Ruta del archivo'
        exe_dlg_ok = 'Confirmar'
        exe_outside = 'Elige un ejecutable solo de la carpeta del juego o de sus subcarpetas.'
        exe_outside_title = 'Ruta no válida'
        ofd_title = 'Selecciona el archivo EXE o BAT del juego'
        ofd_filter = 'Archivos ejecutables (*.exe;*.bat)|*.exe;*.bat|EXE (*.exe)|*.exe|BAT (*.bat)|*.bat'
        reason_title_unconfirmed = 'No se pudo confirmar el título automáticamente.'
        reason_exe_missing = 'No se encontró el ejecutable.'
        reason_multi_exe = 'Se encontraron varios ejecutables — la elección no está garantizada.'
        reason_shortcut_fail = 'No se pudo crear el acceso directo de Steam.'
        reason_save_shortcut = 'No se pudo guardar el acceso directo de Steam.'
        sgdb_chooser_hint = 'Elige una opción. Las más populares aparecen primero. Las miniaturas se cargan en segundo plano.'
        src_tip_steam = 'Fuente: Steam'
        src_tip_sgdb = 'Fuente: SteamGridDB'
        sl_no_appid = 'App ID no especificado — las portadas oficiales de Steam no están disponibles.'
        sl_steam_fetch = 'Obteniendo los recursos oficiales de Steam para el App ID {0}…'
        sl_steam_found = 'Steam: recursos encontrados — {0} de 4.'
        covlang_tip = 'Región de portadas de Steam: {0}. Haz clic para elegir otra.'
        covlang_no_appid = 'Región de portadas: primero se necesita el App ID del juego.'
        covlang_checking = 'Comprobando las regiones de portadas disponibles…'
        covlang_unavailable = 'No se pudieron determinar las regiones de portadas disponibles para este juego.'
        covlang_only_one = 'Solo hay una región de portadas disponible para este juego: {0}.'
        covlang_pick = 'Elige la región de portadas.'
        covlang_loading = 'Cargando portadas de la región “{0}”…'
        covlang_done = 'Región de portadas: {0}. Recursos actualizados: {1}.'
        covlang_fail = 'No se pudieron cargar las portadas de la región “{0}”.'
        covlang_all_sgdb = 'Todas las portadas se eligieron en SteamGridDB — no hay nada que cambiar en la región de Steam.'
        sl_steam_fail = 'Steam: no se pudieron obtener los recursos ({0}).'
        sl_sg_nokey = 'SteamGridDB: no se ha configurado la clave de API.'
        sl_sg_keysaved = 'SteamGridDB: clave de API guardada.'
        sl_sg_need_name = 'SteamGridDB: introduce un título o un App ID.'
        sl_sg_variants = 'SteamGridDB: obteniendo opciones para “{0}”…'
        sl_sg_nocovers = 'SteamGridDB: no hay portadas disponibles para “{0}”.'
        sl_sg_by_id = 'SteamGridDB: buscando por App ID {0}…'
        sl_sg_id_none = 'SteamGridDB: no se encontraron portadas para el App ID {0}.'
        sl_sg_searching = 'SteamGridDB: buscando “{0}”…'
        sl_sg_error = 'SteamGridDB: error — {0}'
        sl_sg_notfound = 'SteamGridDB: no se encontró nada.'
        sl_sg_nogames = 'SteamGridDB: no se encontraron juegos coincidentes.'
        sl_sg_found_fetch = 'SteamGridDB: encontrado “{0}”, obteniendo opciones…'
        sl_sg_loading = 'SteamGridDB: cargando {0}…'
        sl_sg_done = 'SteamGridDB: listo — {0} de 4. Juego: “{1}”.'
        sl_sg_imgfail = 'SteamGridDB: no se pudieron cargar las imágenes.'
        sl_sg_alts = 'SteamGridDB: cargando alternativas para {0}…'
        sl_sg_noalts = 'SteamGridDB: no se encontraron alternativas para este tipo.'
        sl_steam_loaded_alt = 'Steam: portadas oficiales cargadas. SteamGridDB se usa para elegir alternativas.'
        bk_title = 'Copia de seguridad'
        bk_create_fail = 'No se pudo crear una copia de seguridad:'
        sg_variants_fail = 'No se pudieron obtener las opciones de SteamGridDB: {0}'
        sg_pick_fail = 'No se pudo seleccionar la portada: {0}'
        settings_open_fail = 'No se pudieron abrir los ajustes: {0}'
        card_title = 'Ficha del juego — {0}'
        card_name = 'Nombre'
        card_launch = 'Inicio'
        card_params = 'Parámetros'
        card_params_tip = 'Parámetros de inicio'
        slot_vertical = '1. Vertical'
        slot_horizontal = '2. Horizontal'
        slot_hero = '3. Hero / fondo'
        slot_logo = '4. Logotipo'
        card_info = 'Steam es la fuente principal. Al hacer clic en cualquier miniatura se abren las opciones de SteamGridDB solo para ese tipo, sin cambiar toda la fuente.'
        card_save = 'Guardar cambios'
        card_add = 'Añadir juego a la biblioteca'
        card_cancel = 'Cancelar'
        card_skip = 'Omitir'
        badge_exe_manual = 'Ejecutable seleccionado manualmente.'
        badge_opt_ok = 'Los parámetros pertenecen al EXE seleccionado.'
        badge_opt_mismatch = 'Estos parámetros pertenecen a {0}, pero está seleccionado {1}.'
        badge_title_ok = 'Título confirmado con la base de datos de Steam/SteamGridDB.'
        badge_title_fail_src = 'No se pudo confirmar el título en la fuente seleccionada — revísalo manualmente.'
        badge_title_fail_pick = 'No se pudo confirmar el título seleccionado — revísalo manualmente.'
        badge_title_fail_auto = 'No se pudo confirmar el título automáticamente — revísalo manualmente.'
        badge_title_manual = 'El título se cambió manualmente y aún no está confirmado — elige una opción de la lista o busca el juego de nuevo.'
        badge_exe_ok = 'Ejecutable detectado con seguridad.'
        badge_exe_multi = 'Se encontraron varios ejecutables — la elección no está garantizada, revísalo manualmente.'
        badge_exe_none = 'No se encontraron ejecutables — elige el archivo manualmente.'
        badge_exe_steam = 'Ejecutable determinado a partir de los datos de Steam.'
        lo_no_hint = 'Steam no ofrece una descripción aparte de estos parámetros.'
        st_lo_search = 'Steam: buscando parámetros de inicio…'
        st_lo_none = 'Steam: no se encontraron parámetros de inicio para este juego.'
        st_lo_found = 'Steam: opciones de inicio encontradas — {0}'
        st_name_needed_steam = 'Steam: introduce el título del juego.'
        st_name_needed_sgdb = 'SteamGridDB: introduce el título del juego.'
        st_searching_steam = 'Steam: buscando el juego y las portadas oficiales…'
        st_searching_sgdb = 'SteamGridDB: buscando el juego y las portadas…'
        st_notfound_steam = 'Steam: no se encontró ningún juego con este título.'
        st_notfound_sgdb = 'SteamGridDB: no se encontró ningún juego con este título.'
        st_noid_steam = 'Steam: no se pudo determinar el App ID.'
        st_noid_sgdb = 'SteamGridDB: no se pudo determinar el SGDB ID.'
        st_src_error = '{0}: error — {1}'
        st_exe_selected = 'EXE seleccionado: {0}'
        st_no_exe = 'No se encontraron ejecutables.'
        st_pick_noid_steam = 'Steam: no se pudo determinar el App ID de la opción seleccionada.'
        err_pick_noid_sgdb = 'No se pudo determinar el SGDB ID de la opción seleccionada.'
        st_searching_name_steam = 'Steam: buscando “{0}”…'
        st_game_notfound_steam = 'Steam: no se encontró el juego “{0}”.'
        st_no_variants = '{0}: no se encontraron opciones para “{1}”.'
        st_id_digits_steam = 'El App ID solo puede contener dígitos.'
        st_id_digits_sgdb = 'El SGDB ID solo puede contener dígitos.'
        st_resolving_steam = 'Determinando el App ID de Steam y cargando los recursos oficiales de Steam…'
        st_resolving_sgdb = 'Determinando el SGDB ID y cargando los recursos de SteamGridDB…'
        st_covers_loaded = 'Portadas actuales cargadas. Puedes reemplazarlas y guardar los cambios.'
        st_noid_hint_steam = 'Steam: App ID no determinado. Abre la lista junto a “Nombre” o introduce el App ID manualmente.'
        st_noid_hint_sgdb = 'SteamGridDB: SGDB ID no determinado. Abre la lista junto a “Nombre”.'
        st_enter_title = 'Introduce el título del juego.'
        st_pick_exe = 'Elige el archivo EXE o BAT del juego.'
        st_exe_gone = 'El EXE seleccionado ya no existe.'
        st_exe_bat_gone = 'El EXE o BAT seleccionado ya no existe.'
        st_no_workdir = 'No se pudo determinar la carpeta de trabajo del archivo seleccionado.'
        hd_saving = 'Guardando los cambios de “{0}” en Steam…'
        hd_adding = 'Añadiendo “{0}” a Steam…'
        st_done_saved_covers = 'Listo: cambios y portadas guardados.'
        st_saved_no_covers = 'Cambios guardados, pero no se pudieron escribir las portadas.'
        st_done_saved = 'Listo: cambios guardados.'
        st_done_added_covers = 'Listo: juego añadido, portadas aplicadas.'
        st_done_added_nocovers = 'Listo: juego añadido, no se encontraron portadas.'
        st_error = 'Error: {0}'
        hd_classify = 'Clasificando juegos…'
        hd_classify_n = 'Clasificando: {0} ({1}/{2})'
        hd_auto_n = 'Auto: {0} ({1}/{2}) | fichas a continuación: {3}'
        hd_game_error = 'Error en “{0}”: {1}'
        hd_refine_n = 'Refinando: {0} ({1}/{2})'
        hd_queue_left = ' · {0} más en la cola'
        hd_stopped = 'Detenido: correctos {0}, auto {1}, omitidos {2}.'
        hd_finished = 'Listo: {0} de {1} (auto: {2}, omitidos: {3}).'
        hd_auto_batch_err = 'Error en la adición automática en lote: {0}'
        hd_cancelling = 'Cancelando… terminando el juego actual.'
        hd_tick_one = 'Marca al menos un juego.'
        hd_skip_existing = 'Omitiendo juegos ya añadidos: {0}. Continuando con el lote…'
        hd_all_exist = 'Todos los juegos seleccionados ya están en la biblioteca de Steam — no hay nada que añadir.'
        btn_cancel_batch = '✕  Cancelar adición'
        hd_autofill = 'Relleno automático: {0} juegos…'
        hd_cancelled = 'Cancelado: correctos {0} de {1} (automáticos: {2}, omitidos: {3}).'
        hd_autofill_done = 'Relleno automático finalizado: {0} de {1} (automáticos: {2}).'
        hd_autofill_err = 'Error en el relleno automático: {0}'
        hd_card_n = 'Ficha del juego {0} de {1}: {2}'
        hd_batch_cancelled = 'El usuario canceló la adición en lote.'
        hd_skipped = 'Omitido: {0}'
        hd_processing = 'Procesando los juegos seleccionados: {0}.'
        hd_card_err = 'No se pudo abrir la ficha: {0}'
    }
    pt = @{
        hint_main = 'Clique duplo / Enter — abrir a ficha do jogo'
        panel_extra = 'Pasta'
        panel_main = 'Pasta'
        panel_free = '{0} [Livre: {1} {2}]'
        unit_gb = 'GB'
        unit_mb = 'MB'
        unit_kb = 'KB'
        unit_b = 'B'
        path_prefix = 'Caminho: '
        browse = 'Procurar...'
        search_cue = 'Buscar pelo nome da pasta…'
        empty_main = 'Escolha a pasta principal da biblioteca com jogos que não são da Steam'
        empty_extra = 'Escolha a pasta adicional com jogos que não são da Steam (usada para mover jogos temporariamente para um SSD rápido)'
        nothing_found = 'Nada encontrado para “{0}”'
        col_name = 'Nome'
        col_size = 'Tamanho'
        col_date = 'Data'
        col_lib = '✓'
        col_file = 'Arquivo'
        btn_move = 'Mover jogo'
        btn_refresh = 'Atualizar'
        batch_auto = 'Preencher fichas automaticamente'
        batch_auto_tip = 'Se ativado: ao adicionar vários jogos de uma vez, os jogos cujo nome e exe são detectados com segurança são adicionados à biblioteca automaticamente, sem mostrar a ficha. A ficha só é aberta para os jogos que o programa não conseguiu identificar sem ambiguidade.'
        btn_add_batch = '＋  Adicionar jogos selecionados à biblioteca'
        btn_add_batch_n = '＋  Adicionar jogos selecionados à biblioteca ({0})'
        tip_select_all = 'Marcar todos os jogos da lista / limpar todas as marcações'
        tip_lib_header = 'Na biblioteca da Steam (clique para ordenar)'
        tip_row_check = 'Marcar o jogo (para mover ou adicionar em lote)'
        tip_row_installed = 'Este jogo já está na biblioteca da Steam'
        settings_title = 'Configurações'
        settings_desc = 'Abrir as configurações do programa'
        pick_extra_folder = 'Escolha a pasta adicional'
        pick_main_folder = 'Escolha a pasta principal'
        st_sizes_sort = 'Calculando o tamanho das pastas para ordenar: {0} ({1} de {2})'
        st_move_first = 'Primeiro marque um jogo para mover.'
        target_main = 'a pasta principal'
        target_extra = 'a pasta adicional'
        msg_no_space = 'Espaço insuficiente em {0}!'
        err_junction = 'Não foi possível remover a junction: {0}'
        move_title = 'MOVENDO'
        st_copy_progress = '{0}: {1} [Velocidade: {2} MB/s] [{3}%]'
        st_copy_done = '{0}: {1} [100%] — concluído'
        st_move_done = 'Pronto: {0} de {1} movidos para {2}.'
        st_move_err = 'Falha ao mover: {0}'
        st_refresh_start = 'Atualizando a biblioteca da Steam…'
        st_refresh_done = 'Biblioteca da Steam atualizada.'
        st_refresh_err = 'Falha ao atualizar: {0}'
        st_sizes_checked = 'Calculando o tamanho dos jogos marcados: {0} ({1} de {2})'
        st_checked_total = 'Jogos marcados: {0} — tamanho total: {1} {2}'
        st_size_one = 'Tamanho de “{0}”: {1} {2}'
        st_panel_sizes = 'Tamanho calculado de todas as pastas do painel ({0}) — total: {1} {2}'
        st_removed = 'Removidos da lista: {0}. Os arquivos no disco não foram alterados; o botão “Atualizar” traz os jogos de volta.'
        set_language = 'Idioma'
        set_steam_folder = 'Pasta da Steam'
        set_profile = 'Perfil'
        set_profile_hint = 'Escolha o perfil de userdata com o qual o programa vai trabalhar.'
        set_api_key = 'Chave de API'
        key_valid = 'A chave de API é válida.'
        key_invalid_default = 'A chave de API é inválida ou não passou na verificação.'
        key_empty = 'Nenhuma chave de API informada.'
        key_checking = 'Verificando a chave…'
        key_hint_default = 'Necessária para baixar capas de jogos. Você pode obter uma chave gratuita em steamgriddb.com/profile/preferences.'
        key_new_key = ' Nova chave: steamgriddb.com/profile/preferences.'
        sg_401 = 'A chave é inválida ou foi revogada (401).'
        sg_403 = 'Acesso negado (403): a chave foi revogada ou a solicitação foi bloqueada pelo serviço.'
        sg_429 = 'Solicitações demais ao SteamGridDB (429). Tente a verificação novamente mais tarde.'
        sg_server = 'O SteamGridDB está temporariamente indisponível (erro {0}).'
        sg_other = 'Resposta inesperada do SteamGridDB (código {0}).'
        sg_dns = 'Não foi possível encontrar o servidor steamgriddb.com (problema de DNS ou de internet).'
        sg_timeout = 'O SteamGridDB não respondeu em 10 segundos.'
        sg_tls = 'Erro de conexão segura (TLS) com o SteamGridDB.'
        sg_connect = 'Não foi possível conectar ao SteamGridDB (conexão interrompida ou sem internet).'
        sg_noresp = 'Sem resposta do SteamGridDB: {0}'
        set_backup_section = 'Backups do shortcuts.vdf'
        set_backup_current = 'Pasta atual: {0}'
        set_create_backup = 'Criar backup'
        set_restore = 'Restaurar'
        set_cancel = 'Cancelar'
        set_save = 'Salvar'
        set_no_profiles = 'Nenhum perfil da Steam encontrado'
        set_profile_none = 'Não há perfis de userdata na pasta selecionada.'
        set_profile_auto = 'Perfil selecionado automaticamente. Você pode alterá-lo.'
        set_profile_chosen = 'Perfil selecionado: {0}'
        set_profiles_fail = 'Não foi possível ler os perfis'
        pick_steam_folder = 'Escolha a pasta de instalação da Steam'
        pick_backup_folder = 'Escolha a pasta de backups'
        no_backups = 'Ainda não há backups'
        confirm_title = 'Restaurar'
        confirm_q = 'Restaurar o shortcuts.vdf a partir do backup “{0}”?'
        confirm_note = 'A Steam será fechada, o arquivo será substituído e depois a Steam será iniciada novamente.'
        bk_no_source = 'O shortcuts.vdf original deste backup não foi encontrado.'
        bk_ready = 'Pronto para restaurar.'
        bk_created = 'Backups criados: {0}'
        bk_vdf_missing = 'shortcuts.vdf não encontrado.'
        bk_closing = 'Fechando a Steam...'
        bk_no_steam_path = 'Não foi possível determinar o caminho da Steam.'
        bk_restoring = 'Restaurando o arquivo...'
        bk_starting = 'Iniciando a Steam...'
        bk_restored_ok = 'Restaurado e Steam reiniciada: {0}'
        bk_restored_nosteam = 'O arquivo foi restaurado, mas não foi possível iniciar a Steam automaticamente.'
        bk_restore_err = 'Falha ao restaurar: {0}'
        set_path_empty = 'Informe a pasta de instalação da Steam.'
        set_path_missing = 'A pasta da Steam informada não existe.'
        set_exe_missing = 'steam.exe não foi encontrado na pasta selecionada.'
        set_save_err = 'Não foi possível salvar as configurações: {0}'
        vdf_eof = 'O arquivo VDF está truncado ou corrompido (fim inesperado dos dados)'
        vdf_eof_key = 'O arquivo VDF está truncado ou corrompido (terminador do nome da chave não encontrado)'
        vdf_eof_str = 'O arquivo VDF está truncado ou corrompido (terminador do valor de string não encontrado)'
        vdf_eof_int = 'O arquivo VDF está truncado ou corrompido (bytes insuficientes para int32)'
        vdf_bad_field = 'Tipo de campo VDF desconhecido: 0x{0} na posição {1}'
        vdf_bad_type_key = 'O campo “{0}” tem um tipo VDF inesperado.'
        vdf_bad_type = 'Tipo VDF desconhecido: 0x{0}.'
        sc_not_found = 'O atalho existente da Steam não foi encontrado.'
        sc_file_missing = 'Arquivo shortcuts.vdf não encontrado: {0}'
        sc_no_node = 'O objeto “shortcuts” não foi encontrado no shortcuts.vdf.'
        sc_target_gone = 'O atalho que estava sendo editado desapareceu do shortcuts.vdf.'
        sc_exists = 'O jogo “{0}” já está na biblioteca da Steam.'
        sc_userdata_missing = 'Pasta “{0}” não encontrada.'
        sc_node_corrupt = 'O objeto “shortcuts” não foi encontrado no shortcuts.vdf — o arquivo está corrompido ou tem um formato inesperado. Restaure-o a partir de um backup criado manualmente.'
        exe_dlg_title = 'Selecione o arquivo de inicialização — {0}'
        exe_dlg_hint = 'Vários executáveis foram encontrados. Escolha o correto:'
        exe_dlg_col = 'Caminho do arquivo'
        exe_dlg_ok = 'Confirmar'
        exe_outside = 'Escolha um executável apenas da pasta do jogo ou de suas subpastas.'
        exe_outside_title = 'Caminho inválido'
        ofd_title = 'Selecione o arquivo EXE ou BAT do jogo'
        ofd_filter = 'Arquivos executáveis (*.exe;*.bat)|*.exe;*.bat|EXE (*.exe)|*.exe|BAT (*.bat)|*.bat'
        reason_title_unconfirmed = 'Não foi possível confirmar o título automaticamente.'
        reason_exe_missing = 'Executável não encontrado.'
        reason_multi_exe = 'Vários executáveis foram encontrados — a escolha não é garantida.'
        reason_shortcut_fail = 'Falha ao criar o atalho da Steam.'
        reason_save_shortcut = 'Falha ao salvar o atalho da Steam.'
        sgdb_chooser_hint = 'Escolha uma opção. As mais populares aparecem primeiro. As miniaturas são carregadas em segundo plano.'
        src_tip_steam = 'Fonte: Steam'
        src_tip_sgdb = 'Fonte: SteamGridDB'
        sl_no_appid = 'App ID não informado — as capas oficiais da Steam não estão disponíveis.'
        sl_steam_fetch = 'Obtendo os recursos oficiais da Steam para o App ID {0}…'
        sl_steam_found = 'Steam: recursos encontrados — {0} de 4.'
        covlang_tip = 'Região das capas da Steam: {0}. Clique para escolher outra.'
        covlang_no_appid = 'Região das capas: primeiro é necessário o App ID do jogo.'
        covlang_checking = 'Verificando as regiões de capas disponíveis…'
        covlang_unavailable = 'Não foi possível determinar as regiões de capas disponíveis para este jogo.'
        covlang_only_one = 'Apenas uma região de capas está disponível para este jogo: {0}.'
        covlang_pick = 'Escolha a região das capas.'
        covlang_loading = 'Carregando capas da região “{0}”…'
        covlang_done = 'Região das capas: {0}. Recursos atualizados: {1}.'
        covlang_fail = 'Não foi possível carregar as capas da região “{0}”.'
        covlang_all_sgdb = 'Todas as capas foram escolhidas no SteamGridDB — não há nada a alterar na região da Steam.'
        sl_steam_fail = 'Steam: falha ao obter os recursos ({0}).'
        sl_sg_nokey = 'SteamGridDB: a chave de API não foi definida.'
        sl_sg_keysaved = 'SteamGridDB: chave de API salva.'
        sl_sg_need_name = 'SteamGridDB: informe um título ou um App ID.'
        sl_sg_variants = 'SteamGridDB: obtendo opções para “{0}”…'
        sl_sg_nocovers = 'SteamGridDB: não há capas disponíveis para “{0}”.'
        sl_sg_by_id = 'SteamGridDB: buscando pelo App ID {0}…'
        sl_sg_id_none = 'SteamGridDB: nenhuma capa encontrada para o App ID {0}.'
        sl_sg_searching = 'SteamGridDB: buscando “{0}”…'
        sl_sg_error = 'SteamGridDB: erro — {0}'
        sl_sg_notfound = 'SteamGridDB: nada encontrado.'
        sl_sg_nogames = 'SteamGridDB: nenhum jogo correspondente encontrado.'
        sl_sg_found_fetch = 'SteamGridDB: “{0}” encontrado, obtendo opções…'
        sl_sg_loading = 'SteamGridDB: carregando {0}…'
        sl_sg_done = 'SteamGridDB: pronto — {0} de 4. Jogo: “{1}”.'
        sl_sg_imgfail = 'SteamGridDB: falha ao carregar as imagens.'
        sl_sg_alts = 'SteamGridDB: carregando alternativas para {0}…'
        sl_sg_noalts = 'SteamGridDB: nenhuma alternativa encontrada para este tipo.'
        sl_steam_loaded_alt = 'Steam: capas oficiais carregadas. O SteamGridDB é usado para escolher alternativas.'
        bk_title = 'Backup'
        bk_create_fail = 'Não foi possível criar um backup:'
        sg_variants_fail = 'Não foi possível obter as opções do SteamGridDB: {0}'
        sg_pick_fail = 'Não foi possível selecionar a capa: {0}'
        settings_open_fail = 'Não foi possível abrir as configurações: {0}'
        card_title = 'Ficha do jogo — {0}'
        card_name = 'Nome'
        card_launch = 'Inicialização'
        card_params = 'Parâmetros'
        card_params_tip = 'Parâmetros de inicialização'
        slot_vertical = '1. Vertical'
        slot_horizontal = '2. Horizontal'
        slot_hero = '3. Hero / plano de fundo'
        slot_logo = '4. Logotipo'
        card_info = 'A Steam é a fonte principal. Ao clicar em qualquer miniatura, abrem-se as opções do SteamGridDB apenas para aquele tipo, sem trocar a fonte inteira.'
        card_save = 'Salvar alterações'
        card_add = 'Adicionar jogo à biblioteca'
        card_cancel = 'Cancelar'
        card_skip = 'Pular'
        badge_exe_manual = 'Executável selecionado manualmente.'
        badge_opt_ok = 'Os parâmetros pertencem ao EXE selecionado.'
        badge_opt_mismatch = 'Estes parâmetros pertencem a {0}, mas {1} está selecionado.'
        badge_title_ok = 'Título confirmado no banco de dados da Steam/SteamGridDB.'
        badge_title_fail_src = 'Não foi possível confirmar o título na fonte selecionada — verifique manualmente.'
        badge_title_fail_pick = 'Não foi possível confirmar o título selecionado — verifique manualmente.'
        badge_title_fail_auto = 'Não foi possível confirmar o título automaticamente — verifique manualmente.'
        badge_title_manual = 'O título foi alterado manualmente e ainda não foi confirmado — escolha uma opção da lista ou busque o jogo novamente.'
        badge_exe_ok = 'Executável detectado com segurança.'
        badge_exe_multi = 'Vários executáveis foram encontrados — a escolha não é garantida, verifique manualmente.'
        badge_exe_none = 'Nenhum executável encontrado — escolha o arquivo manualmente.'
        badge_exe_steam = 'Executável determinado a partir dos dados da Steam.'
        lo_no_hint = 'A Steam não fornece uma descrição separada para estes parâmetros.'
        st_lo_search = 'Steam: procurando parâmetros de inicialização…'
        st_lo_none = 'Steam: nenhum parâmetro de inicialização encontrado para este jogo.'
        st_lo_found = 'Steam: opções de inicialização encontradas — {0}'
        st_name_needed_steam = 'Steam: informe o título do jogo.'
        st_name_needed_sgdb = 'SteamGridDB: informe o título do jogo.'
        st_searching_steam = 'Steam: buscando o jogo e as capas oficiais…'
        st_searching_sgdb = 'SteamGridDB: buscando o jogo e as capas…'
        st_notfound_steam = 'Steam: nenhum jogo encontrado com este título.'
        st_notfound_sgdb = 'SteamGridDB: nenhum jogo encontrado com este título.'
        st_noid_steam = 'Steam: não foi possível determinar o App ID.'
        st_noid_sgdb = 'SteamGridDB: não foi possível determinar o SGDB ID.'
        st_src_error = '{0}: erro — {1}'
        st_exe_selected = 'EXE selecionado: {0}'
        st_no_exe = 'Nenhum executável encontrado.'
        st_pick_noid_steam = 'Steam: não foi possível determinar o App ID da opção selecionada.'
        err_pick_noid_sgdb = 'Não foi possível determinar o SGDB ID da opção selecionada.'
        st_searching_name_steam = 'Steam: buscando “{0}”…'
        st_game_notfound_steam = 'Steam: jogo “{0}” não encontrado.'
        st_no_variants = '{0}: nenhuma opção encontrada para “{1}”.'
        st_id_digits_steam = 'O App ID deve conter apenas dígitos.'
        st_id_digits_sgdb = 'O SGDB ID deve conter apenas dígitos.'
        st_resolving_steam = 'Determinando o App ID da Steam e carregando os recursos oficiais da Steam…'
        st_resolving_sgdb = 'Determinando o SGDB ID e carregando os recursos do SteamGridDB…'
        st_covers_loaded = 'Capas atuais carregadas. Você pode substituí-las e salvar as alterações.'
        st_noid_hint_steam = 'Steam: App ID não determinado. Abra a lista ao lado de “Nome” ou informe o App ID manualmente.'
        st_noid_hint_sgdb = 'SteamGridDB: SGDB ID não determinado. Abra a lista ao lado de “Nome”.'
        st_enter_title = 'Informe o título do jogo.'
        st_pick_exe = 'Escolha o arquivo EXE ou BAT do jogo.'
        st_exe_gone = 'O EXE selecionado não existe mais.'
        st_exe_bat_gone = 'O EXE ou BAT selecionado não existe mais.'
        st_no_workdir = 'Não foi possível determinar a pasta de trabalho do arquivo selecionado.'
        hd_saving = 'Salvando as alterações de “{0}” na Steam…'
        hd_adding = 'Adicionando “{0}” à Steam…'
        st_done_saved_covers = 'Pronto: alterações e capas salvas.'
        st_saved_no_covers = 'Alterações salvas, mas não foi possível gravar as capas.'
        st_done_saved = 'Pronto: alterações salvas.'
        st_done_added_covers = 'Pronto: jogo adicionado, capas aplicadas.'
        st_done_added_nocovers = 'Pronto: jogo adicionado, nenhuma capa encontrada.'
        st_error = 'Erro: {0}'
        hd_classify = 'Classificando jogos…'
        hd_classify_n = 'Classificando: {0} ({1}/{2})'
        hd_auto_n = 'Auto: {0} ({1}/{2}) | fichas a seguir: {3}'
        hd_game_error = 'Erro em “{0}”: {1}'
        hd_refine_n = 'Refinando: {0} ({1}/{2})'
        hd_queue_left = ' · mais {0} na fila'
        hd_stopped = 'Interrompido: OK {0}, auto {1}, pulados {2}.'
        hd_finished = 'Pronto: {0} de {1} (auto: {2}, pulados: {3}).'
        hd_auto_batch_err = 'Falha na adição automática em lote: {0}'
        hd_cancelling = 'Cancelando… concluindo o jogo atual.'
        hd_tick_one = 'Marque pelo menos um jogo.'
        hd_skip_existing = 'Pulando jogos já adicionados: {0}. Continuando o lote…'
        hd_all_exist = 'Todos os jogos selecionados já estão na biblioteca da Steam — nada a adicionar.'
        btn_cancel_batch = '✕  Cancelar adição'
        hd_autofill = 'Preenchimento automático: {0} jogos…'
        hd_cancelled = 'Cancelado: OK {0} de {1} (automáticos: {2}, pulados: {3}).'
        hd_autofill_done = 'Preenchimento automático concluído: {0} de {1} (automáticos: {2}).'
        hd_autofill_err = 'Falha no preenchimento automático: {0}'
        hd_card_n = 'Ficha do jogo {0} de {1}: {2}'
        hd_batch_cancelled = 'A adição em lote foi cancelada pelo usuário.'
        hd_skipped = 'Pulado: {0}'
        hd_processing = 'Processando os jogos selecionados: {0}.'
        hd_card_err = 'Não foi possível abrir a ficha: {0}'
    }
    de = @{
        hint_main = 'Doppelklick / Eingabe — Spielkarte öffnen'
        panel_extra = 'Ordner'
        panel_main = 'Ordner'
        panel_free = '{0} [Frei: {1} {2}]'
        unit_gb = 'GB'
        unit_mb = 'MB'
        unit_kb = 'KB'
        unit_b = 'B'
        path_prefix = 'Pfad: '
        browse = 'Durchsuchen...'
        search_cue = 'Nach Ordnername suchen…'
        empty_main = 'Wähle den Hauptordner der Bibliothek mit Non-Steam-Spielen aus'
        empty_extra = 'Wähle den zusätzlichen Ordner mit Non-Steam-Spielen aus (dient zum vorübergehenden Verschieben von Spielen auf eine schnelle SSD)'
        nothing_found = 'Nichts gefunden für „{0}“'
        col_name = 'Name'
        col_size = 'Größe'
        col_date = 'Datum'
        col_lib = '✓'
        col_file = 'Datei'
        btn_move = 'Spiel verschieben'
        btn_refresh = 'Aktualisieren'
        batch_auto = 'Karten automatisch ausfüllen'
        batch_auto_tip = 'Wenn aktiviert: Beim gleichzeitigen Hinzufügen mehrerer Spiele werden Spiele, deren Name und exe sicher erkannt wurden, automatisch der Bibliothek hinzugefügt, ohne dass die Karte angezeigt wird. Die Karte öffnet sich nur bei Spielen, die das Programm nicht eindeutig identifizieren konnte.'
        btn_add_batch = '＋  Ausgewählte Spiele zur Bibliothek hinzufügen'
        btn_add_batch_n = '＋  Ausgewählte Spiele zur Bibliothek hinzufügen ({0})'
        tip_select_all = 'Alle Spiele in der Liste anhaken / alle Häkchen entfernen'
        tip_lib_header = 'In der Steam-Bibliothek (zum Sortieren klicken)'
        tip_row_check = 'Spiel anhaken (zum Verschieben oder Stapel-Hinzufügen)'
        tip_row_installed = 'Dieses Spiel ist bereits in der Steam-Bibliothek'
        settings_title = 'Einstellungen'
        settings_desc = 'Programmeinstellungen öffnen'
        pick_extra_folder = 'Zusätzlichen Ordner auswählen'
        pick_main_folder = 'Hauptordner auswählen'
        st_sizes_sort = 'Ordnergrößen werden zum Sortieren berechnet: {0} ({1} von {2})'
        st_move_first = 'Hake zuerst ein Spiel zum Verschieben an.'
        target_main = 'den Hauptordner'
        target_extra = 'den zusätzlichen Ordner'
        msg_no_space = 'Nicht genug Speicherplatz auf {0}!'
        err_junction = 'Junction konnte nicht entfernt werden: {0}'
        move_title = 'VERSCHIEBEN'
        st_copy_progress = '{0}: {1} [Geschwindigkeit: {2} MB/s] [{3}%]'
        st_copy_done = '{0}: {1} [100%] — abgeschlossen'
        st_move_done = 'Fertig: {0} von {1} in {2} verschoben.'
        st_move_err = 'Verschieben fehlgeschlagen: {0}'
        st_refresh_start = 'Steam-Bibliothek wird aktualisiert…'
        st_refresh_done = 'Steam-Bibliothek aktualisiert.'
        st_refresh_err = 'Aktualisierung fehlgeschlagen: {0}'
        st_sizes_checked = 'Größe der angehakten Spiele wird berechnet: {0} ({1} von {2})'
        st_checked_total = 'Angehakte Spiele: {0} — Gesamtgröße: {1} {2}'
        st_size_one = 'Größe von „{0}“: {1} {2}'
        st_panel_sizes = 'Größe aller Ordner im Bereich ({0}) berechnet — gesamt: {1} {2}'
        st_removed = 'Aus der Liste entfernt: {0}. Die Dateien auf dem Datenträger bleiben unverändert; mit „Aktualisieren“ kommen die Spiele zurück.'
        set_language = 'Sprache'
        set_steam_folder = 'Steam-Ordner'
        set_profile = 'Profil'
        set_profile_hint = 'Wähle das userdata-Profil aus, mit dem das Programm arbeiten soll.'
        set_api_key = 'API-Schlüssel'
        key_valid = 'Der API-Schlüssel ist gültig.'
        key_invalid_default = 'Der API-Schlüssel ist ungültig oder hat die Prüfung nicht bestanden.'
        key_empty = 'Kein API-Schlüssel eingegeben.'
        key_checking = 'Schlüssel wird geprüft…'
        key_hint_default = 'Wird zum Herunterladen von Spiele-Covern benötigt. Einen kostenlosen Schlüssel gibt es unter steamgriddb.com/profile/preferences.'
        key_new_key = ' Neuer Schlüssel: steamgriddb.com/profile/preferences.'
        sg_401 = 'Der Schlüssel ist ungültig oder wurde widerrufen (401).'
        sg_403 = 'Zugriff verweigert (403): Der Schlüssel wurde widerrufen oder die Anfrage wurde vom Dienst blockiert.'
        sg_429 = 'Zu viele Anfragen an SteamGridDB (429). Versuche die Prüfung später erneut.'
        sg_server = 'SteamGridDB ist vorübergehend nicht erreichbar (Fehler {0}).'
        sg_other = 'Unerwartete Antwort von SteamGridDB (Code {0}).'
        sg_dns = 'Der Server steamgriddb.com wurde nicht gefunden (DNS- oder Internetproblem).'
        sg_timeout = 'SteamGridDB hat nicht innerhalb von 10 Sekunden geantwortet.'
        sg_tls = 'Fehler bei der sicheren Verbindung (TLS) zu SteamGridDB.'
        sg_connect = 'Verbindung zu SteamGridDB nicht möglich (Verbindung unterbrochen oder kein Internet).'
        sg_noresp = 'Keine Antwort von SteamGridDB: {0}'
        set_backup_section = 'Sicherungen von shortcuts.vdf'
        set_backup_current = 'Aktueller Ordner: {0}'
        set_create_backup = 'Sicherung erstellen'
        set_restore = 'Wiederherstellen'
        set_cancel = 'Abbrechen'
        set_save = 'Speichern'
        set_no_profiles = 'Keine Steam-Profile gefunden'
        set_profile_none = 'Im gewählten Ordner gibt es keine userdata-Profile.'
        set_profile_auto = 'Profil automatisch ausgewählt. Du kannst es ändern.'
        set_profile_chosen = 'Ausgewähltes Profil: {0}'
        set_profiles_fail = 'Profile konnten nicht gelesen werden'
        pick_steam_folder = 'Steam-Installationsordner auswählen'
        pick_backup_folder = 'Sicherungsordner auswählen'
        no_backups = 'Noch keine Sicherungen vorhanden'
        confirm_title = 'Wiederherstellen'
        confirm_q = 'shortcuts.vdf aus der Sicherung „{0}“ wiederherstellen?'
        confirm_note = 'Steam wird beendet, die Datei ersetzt und Steam anschließend neu gestartet.'
        bk_no_source = 'Die ursprüngliche shortcuts.vdf zu dieser Sicherung wurde nicht gefunden.'
        bk_ready = 'Bereit zur Wiederherstellung.'
        bk_created = 'Sicherungen erstellt: {0}'
        bk_vdf_missing = 'shortcuts.vdf nicht gefunden.'
        bk_closing = 'Steam wird beendet...'
        bk_no_steam_path = 'Der Steam-Pfad konnte nicht ermittelt werden.'
        bk_restoring = 'Datei wird wiederhergestellt...'
        bk_starting = 'Steam wird gestartet...'
        bk_restored_ok = 'Wiederhergestellt und Steam neu gestartet: {0}'
        bk_restored_nosteam = 'Die Datei wurde wiederhergestellt, Steam konnte aber nicht automatisch gestartet werden.'
        bk_restore_err = 'Wiederherstellung fehlgeschlagen: {0}'
        set_path_empty = 'Gib den Steam-Installationsordner an.'
        set_path_missing = 'Der angegebene Steam-Ordner existiert nicht.'
        set_exe_missing = 'steam.exe wurde im gewählten Ordner nicht gefunden.'
        set_save_err = 'Einstellungen konnten nicht gespeichert werden: {0}'
        vdf_eof = 'Die VDF-Datei ist abgeschnitten oder beschädigt (unerwartetes Datenende)'
        vdf_eof_key = 'Die VDF-Datei ist abgeschnitten oder beschädigt (Abschluss des Schlüsselnamens nicht gefunden)'
        vdf_eof_str = 'Die VDF-Datei ist abgeschnitten oder beschädigt (Abschluss des Zeichenkettenwerts nicht gefunden)'
        vdf_eof_int = 'Die VDF-Datei ist abgeschnitten oder beschädigt (zu wenige Bytes für int32)'
        vdf_bad_field = 'Unbekannter VDF-Feldtyp: 0x{0} an Position {1}'
        vdf_bad_type_key = 'Das Feld „{0}“ hat einen unerwarteten VDF-Typ.'
        vdf_bad_type = 'Unbekannter VDF-Typ: 0x{0}.'
        sc_not_found = 'Die vorhandene Steam-Verknüpfung wurde nicht gefunden.'
        sc_file_missing = 'Datei shortcuts.vdf nicht gefunden: {0}'
        sc_no_node = 'Das Objekt „shortcuts“ wurde in shortcuts.vdf nicht gefunden.'
        sc_target_gone = 'Die bearbeitete Verknüpfung ist aus shortcuts.vdf verschwunden.'
        sc_exists = 'Das Spiel „{0}“ ist bereits in der Steam-Bibliothek.'
        sc_userdata_missing = 'Ordner „{0}“ nicht gefunden.'
        sc_node_corrupt = 'Das Objekt „shortcuts“ wurde in shortcuts.vdf nicht gefunden — die Datei ist beschädigt oder hat ein unerwartetes Format. Stelle sie aus einer manuell erstellten Sicherung wieder her.'
        exe_dlg_title = 'Startdatei auswählen — {0}'
        exe_dlg_hint = 'Es wurden mehrere ausführbare Dateien gefunden. Wähle die richtige aus:'
        exe_dlg_col = 'Dateipfad'
        exe_dlg_ok = 'Bestätigen'
        exe_outside = 'Wähle eine ausführbare Datei nur aus dem Spielordner oder dessen Unterordnern.'
        exe_outside_title = 'Ungültiger Pfad'
        ofd_title = 'EXE- oder BAT-Datei des Spiels auswählen'
        ofd_filter = 'Ausführbare Dateien (*.exe;*.bat)|*.exe;*.bat|EXE (*.exe)|*.exe|BAT (*.bat)|*.bat'
        reason_title_unconfirmed = 'Der Titel konnte nicht automatisch bestätigt werden.'
        reason_exe_missing = 'Ausführbare Datei nicht gefunden.'
        reason_multi_exe = 'Mehrere ausführbare Dateien gefunden — die Auswahl ist nicht gesichert.'
        reason_shortcut_fail = 'Die Steam-Verknüpfung konnte nicht erstellt werden.'
        reason_save_shortcut = 'Die Steam-Verknüpfung konnte nicht gespeichert werden.'
        sgdb_chooser_hint = 'Wähle eine Option aus. Die beliebtesten werden zuerst angezeigt. Vorschaubilder werden im Hintergrund geladen.'
        src_tip_steam = 'Quelle: Steam'
        src_tip_sgdb = 'Quelle: SteamGridDB'
        sl_no_appid = 'App-ID nicht angegeben — offizielle Steam-Cover sind nicht verfügbar.'
        sl_steam_fetch = 'Offizielle Steam-Assets für App-ID {0} werden abgerufen…'
        sl_steam_found = 'Steam: Assets gefunden — {0} von 4.'
        covlang_tip = 'Steam-Cover-Region: {0}. Klicken, um eine andere auszuwählen.'
        covlang_no_appid = 'Cover-Region: Zuerst wird die App-ID des Spiels benötigt.'
        covlang_checking = 'Verfügbare Cover-Regionen werden geprüft…'
        covlang_unavailable = 'Die verfügbaren Cover-Regionen für dieses Spiel konnten nicht ermittelt werden.'
        covlang_only_one = 'Für dieses Spiel ist nur eine Cover-Region verfügbar: {0}.'
        covlang_pick = 'Cover-Region auswählen.'
        covlang_loading = 'Cover für die Region „{0}“ werden geladen…'
        covlang_done = 'Cover-Region: {0}. Aktualisierte Assets: {1}.'
        covlang_fail = 'Cover für die Region „{0}“ konnten nicht geladen werden.'
        covlang_all_sgdb = 'Alle Cover wurden aus SteamGridDB gewählt — an der Steam-Region gibt es nichts zu ändern.'
        sl_steam_fail = 'Steam: Assets konnten nicht abgerufen werden ({0}).'
        sl_sg_nokey = 'SteamGridDB: API-Schlüssel ist nicht festgelegt.'
        sl_sg_keysaved = 'SteamGridDB: API-Schlüssel gespeichert.'
        sl_sg_need_name = 'SteamGridDB: Gib einen Titel oder eine App-ID ein.'
        sl_sg_variants = 'SteamGridDB: Optionen für „{0}“ werden abgerufen…'
        sl_sg_nocovers = 'SteamGridDB: Keine Cover für „{0}“ verfügbar.'
        sl_sg_by_id = 'SteamGridDB: Suche nach App-ID {0}…'
        sl_sg_id_none = 'SteamGridDB: Keine Cover für App-ID {0} gefunden.'
        sl_sg_searching = 'SteamGridDB: Suche nach „{0}“…'
        sl_sg_error = 'SteamGridDB: Fehler — {0}'
        sl_sg_notfound = 'SteamGridDB: Nichts gefunden.'
        sl_sg_nogames = 'SteamGridDB: Keine passenden Spiele gefunden.'
        sl_sg_found_fetch = 'SteamGridDB: „{0}“ gefunden, Optionen werden abgerufen…'
        sl_sg_loading = 'SteamGridDB: {0} wird geladen…'
        sl_sg_done = 'SteamGridDB: Fertig — {0} von 4. Spiel: „{1}“.'
        sl_sg_imgfail = 'SteamGridDB: Bilder konnten nicht geladen werden.'
        sl_sg_alts = 'SteamGridDB: Alternativen für {0} werden geladen…'
        sl_sg_noalts = 'SteamGridDB: Keine Alternativen für diesen Typ gefunden.'
        sl_steam_loaded_alt = 'Steam: Offizielle Cover geladen. SteamGridDB dient zur Auswahl von Alternativen.'
        bk_title = 'Sicherung'
        bk_create_fail = 'Sicherung konnte nicht erstellt werden:'
        sg_variants_fail = 'SteamGridDB-Optionen konnten nicht abgerufen werden: {0}'
        sg_pick_fail = 'Cover konnte nicht ausgewählt werden: {0}'
        settings_open_fail = 'Einstellungen konnten nicht geöffnet werden: {0}'
        card_title = 'Spielkarte — {0}'
        card_name = 'Name'
        card_launch = 'Start'
        card_params = 'Parameter'
        card_params_tip = 'Startparameter'
        slot_vertical = '1. Hochformat'
        slot_horizontal = '2. Querformat'
        slot_hero = '3. Hero / Hintergrund'
        slot_logo = '4. Logo'
        card_info = 'Steam ist die Hauptquelle. Ein Klick auf ein beliebiges Vorschaubild öffnet die SteamGridDB-Optionen nur für diesen Typ, ohne die gesamte Quelle zu wechseln.'
        card_save = 'Änderungen speichern'
        card_add = 'Spiel zur Bibliothek hinzufügen'
        card_cancel = 'Abbrechen'
        card_skip = 'Überspringen'
        badge_exe_manual = 'Ausführbare Datei manuell ausgewählt.'
        badge_opt_ok = 'Die Parameter gehören zur ausgewählten EXE.'
        badge_opt_mismatch = 'Diese Parameter gehören zu {0}, ausgewählt ist aber {1}.'
        badge_title_ok = 'Titel anhand der Steam-/SteamGridDB-Datenbank bestätigt.'
        badge_title_fail_src = 'Der Titel konnte in der gewählten Quelle nicht bestätigt werden — bitte manuell prüfen.'
        badge_title_fail_pick = 'Der gewählte Titel konnte nicht bestätigt werden — bitte manuell prüfen.'
        badge_title_fail_auto = 'Der Titel konnte nicht automatisch bestätigt werden — bitte manuell prüfen.'
        badge_title_manual = 'Der Titel wurde manuell geändert und ist noch nicht bestätigt — wähle eine Option aus der Liste oder suche das Spiel erneut.'
        badge_exe_ok = 'Ausführbare Datei sicher erkannt.'
        badge_exe_multi = 'Mehrere ausführbare Dateien gefunden — die Auswahl ist nicht gesichert, bitte manuell prüfen.'
        badge_exe_none = 'Keine ausführbaren Dateien gefunden — wähle die Datei manuell aus.'
        badge_exe_steam = 'Ausführbare Datei anhand von Steam-Daten ermittelt.'
        lo_no_hint = 'Steam liefert keine separate Beschreibung für diese Parameter.'
        st_lo_search = 'Steam: Startparameter werden gesucht…'
        st_lo_none = 'Steam: Keine Startparameter für dieses Spiel gefunden.'
        st_lo_found = 'Steam: Startoptionen gefunden — {0}'
        st_name_needed_steam = 'Steam: Gib den Spieltitel ein.'
        st_name_needed_sgdb = 'SteamGridDB: Gib den Spieltitel ein.'
        st_searching_steam = 'Steam: Suche nach dem Spiel und den offiziellen Covern…'
        st_searching_sgdb = 'SteamGridDB: Suche nach dem Spiel und den Covern…'
        st_notfound_steam = 'Steam: Kein Spiel mit diesem Titel gefunden.'
        st_notfound_sgdb = 'SteamGridDB: Kein Spiel mit diesem Titel gefunden.'
        st_noid_steam = 'Steam: App-ID konnte nicht ermittelt werden.'
        st_noid_sgdb = 'SteamGridDB: SGDB-ID konnte nicht ermittelt werden.'
        st_src_error = '{0}: Fehler — {1}'
        st_exe_selected = 'Ausgewählte EXE: {0}'
        st_no_exe = 'Keine ausführbaren Dateien gefunden.'
        st_pick_noid_steam = 'Steam: Die App-ID der gewählten Option konnte nicht ermittelt werden.'
        err_pick_noid_sgdb = 'Die SGDB-ID der gewählten Option konnte nicht ermittelt werden.'
        st_searching_name_steam = 'Steam: Suche nach „{0}“…'
        st_game_notfound_steam = 'Steam: Spiel „{0}“ nicht gefunden.'
        st_no_variants = '{0}: Keine Optionen für „{1}“ gefunden.'
        st_id_digits_steam = 'Die App-ID darf nur Ziffern enthalten.'
        st_id_digits_sgdb = 'Die SGDB-ID darf nur Ziffern enthalten.'
        st_resolving_steam = 'Steam-App-ID wird ermittelt und offizielle Steam-Assets werden geladen…'
        st_resolving_sgdb = 'SGDB-ID wird ermittelt und SteamGridDB-Assets werden geladen…'
        st_covers_loaded = 'Aktuelle Cover geladen. Du kannst sie ersetzen und die Änderungen speichern.'
        st_noid_hint_steam = 'Steam: App-ID nicht ermittelt. Öffne die Liste neben „Name“ oder gib die App-ID manuell ein.'
        st_noid_hint_sgdb = 'SteamGridDB: SGDB-ID nicht ermittelt. Öffne die Liste neben „Name“.'
        st_enter_title = 'Gib den Spieltitel ein.'
        st_pick_exe = 'Wähle die EXE- oder BAT-Datei des Spiels aus.'
        st_exe_gone = 'Die gewählte EXE existiert nicht mehr.'
        st_exe_bat_gone = 'Die gewählte EXE oder BAT existiert nicht mehr.'
        st_no_workdir = 'Der Arbeitsordner der gewählten Datei konnte nicht ermittelt werden.'
        hd_saving = 'Änderungen an „{0}“ werden in Steam gespeichert…'
        hd_adding = '„{0}“ wird zu Steam hinzugefügt…'
        st_done_saved_covers = 'Fertig: Änderungen und Cover gespeichert.'
        st_saved_no_covers = 'Änderungen gespeichert, die Cover konnten aber nicht geschrieben werden.'
        st_done_saved = 'Fertig: Änderungen gespeichert.'
        st_done_added_covers = 'Fertig: Spiel hinzugefügt, Cover angewendet.'
        st_done_added_nocovers = 'Fertig: Spiel hinzugefügt, keine Cover gefunden.'
        st_error = 'Fehler: {0}'
        hd_classify = 'Spiele werden klassifiziert…'
        hd_classify_n = 'Klassifizierung: {0} ({1}/{2})'
        hd_auto_n = 'Auto: {0} ({1}/{2}) | Karten danach: {3}'
        hd_game_error = 'Fehler bei „{0}“: {1}'
        hd_refine_n = 'Verfeinerung: {0} ({1}/{2})'
        hd_queue_left = ' · noch {0} in der Warteschlange'
        hd_stopped = 'Gestoppt: OK {0}, auto {1}, übersprungen {2}.'
        hd_finished = 'Fertig: {0} von {1} (auto: {2}, übersprungen: {3}).'
        hd_auto_batch_err = 'Automatisches Stapel-Hinzufügen fehlgeschlagen: {0}'
        hd_cancelling = 'Abbruch… das aktuelle Spiel wird noch abgeschlossen.'
        hd_tick_one = 'Hake mindestens ein Spiel an.'
        hd_skip_existing = 'Bereits hinzugefügte Spiele werden übersprungen: {0}. Stapel wird fortgesetzt…'
        hd_all_exist = 'Alle ausgewählten Spiele sind bereits in der Steam-Bibliothek — nichts hinzuzufügen.'
        btn_cancel_batch = '✕  Hinzufügen abbrechen'
        hd_autofill = 'Automatisches Ausfüllen: {0} Spiele…'
        hd_cancelled = 'Abgebrochen: OK {0} von {1} (automatisch: {2}, übersprungen: {3}).'
        hd_autofill_done = 'Automatisches Ausfüllen abgeschlossen: {0} von {1} (automatisch: {2}).'
        hd_autofill_err = 'Automatisches Ausfüllen fehlgeschlagen: {0}'
        hd_card_n = 'Spielkarte {0} von {1}: {2}'
        hd_batch_cancelled = 'Das Stapel-Hinzufügen wurde vom Benutzer abgebrochen.'
        hd_skipped = 'Übersprungen: {0}'
        hd_processing = 'Ausgewählte Spiele werden verarbeitet: {0}.'
        hd_card_err = 'Die Karte konnte nicht geöffnet werden: {0}'
    }
}

function T ([string]$Key, [object[]]$FormatArgs = @()) {
    $lang = [string]$global:language
    $text = $null
    if ($script:I18n.ContainsKey($lang) -and $script:I18n[$lang].ContainsKey($Key)) {
        $text = [string]$script:I18n[$lang][$Key]
    } elseif ($script:I18n['ru'].ContainsKey($Key)) {
        $text = [string]$script:I18n['ru'][$Key]
    } else {
        return $Key
    }
    if ($FormatArgs.Count -gt 0) { return ($text -f $FormatArgs) }
    return $text
}
# Все постоянные настройки и служебные метаданные хранятся в профиле
# пользователя, а не рядом с EXE. Благодаря этому каталог программы может
# содержать только один Steam Commander.exe.
$global:appDataDir = Join-Path ([Environment]::GetFolderPath('ApplicationData')) "Steam Commander"
$global:coverSourcesDir = Join-Path $global:appDataDir "cover_sources"
# API-ключ SteamGridDB (бесплатный, получается на steamgriddb.com/profile/preferences)
# — используется как резервный источник обложек, когда у официального CDN
# Steam нет нужных картинок (совсем новые/непопулярные издания, только hero
# без капсулы и т.п.). Хранится в config.ini рядом с остальными настройками.
$global:steamGridDbApiKey = ""
# Состояние последней проверки ключа SteamGridDB. До успешной проверки
# SGDB-поиск считается недоступным.
$global:steamGridDbApiKeyValid = $false

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $osLang = ''; try { $osLang = [System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName } catch {}
    $adminMsg = switch ($osLang) { 'ru' { @('Запустите программу от имени АДМИНИСТРАТОРА!', 'Ошибка') } 'zh' { @('请以管理员身份运行本程序！', '错误') } 'es' { @('¡Ejecuta el programa como ADMINISTRADOR!', 'Error') } 'pt' { @('Execute o programa como ADMINISTRADOR!', 'Erro') } 'de' { @('Starte das Programm als ADMINISTRATOR!', 'Fehler') } default { @('Run the program as ADMINISTRATOR!', 'Error') } }
    [System.Windows.Forms.MessageBox]::Show($adminMsg[0], $adminMsg[1], [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit
}

function Create-InitialDirs {
    # Постоянные данные программы находятся в %APPDATA%\Steam Commander.
    # Рядом с EXE ничего не создаём.
    if (-not (Test-Path $global:appDataDir)) {
        New-Item -ItemType Directory -Path $global:appDataDir -Force | Out-Null
    }
    if (-not (Test-Path $global:coverSourcesDir)) {
        New-Item -ItemType Directory -Path $global:coverSourcesDir -Force | Out-Null
    }
}
Create-InitialDirs
function Get-FolderSize ($path) {
    $size = 0
    Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $size += $_.Length }
    return $size
}

function Clean-GameName ($itemText) {
    return ($itemText -replace "\s*\(\d+(?:[.,]\d+)?\s*(?:ГБ|МБ|КБ|GB|MB|KB)\)", "").Trim()
}

# ЭТОЙ ФУНКЦИИ НЕ БЫЛО В ФАЙЛЕ ВООБЩЕ — отсюда были "сломаны" все три кнопки "..."
function Test-FileInsideRoot ($filePath, $rootPath) {
    if ([string]::IsNullOrWhiteSpace([string]$filePath) -or [string]::IsNullOrWhiteSpace([string]$rootPath)) { return $false }
    try {
        $fileFull = [System.IO.Path]::GetFullPath([string]$filePath).TrimEnd('\')
        $rootFull = [System.IO.Path]::GetFullPath([string]$rootPath).TrimEnd('\')
        $prefix = $rootFull + '\'
        return $fileFull.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
    } catch {
        return $false
    }
}

function Show-CenteredFolderDialog ($description, $initialPath) {
    # $form ещё не создана в момент ОПРЕДЕЛЕНИЯ этой функции, но к моменту её ВЫЗОВА
    # (из обработчиков кнопок) форма уже существует — PowerShell разрешает $form по имени
    # в момент выполнения, а не в момент объявления функции.
    $ownerHandle = [IntPtr]::Zero
    if ((Test-Path variable:form) -and ($form -ne $null)) { $ownerHandle = $form.Handle }

    try {
        # Современный диалог Проводника (IFileOpenDialog + FOS_PICKFOLDERS) —
        # тот же, что открывается через "Обзор" в самой Windows.
        $dialog = New-Object ModernDialogs.VistaFolderBrowserDialog
        $dialog.Description = $description
        if ((-not [string]::IsNullOrEmpty($initialPath)) -and (Test-Path $initialPath)) {
            $dialog.SelectedPath = $initialPath
        }
        if ($dialog.ShowDialog($ownerHandle)) {
            return $dialog.SelectedPath
        }
        return $null
    } catch {
        # Резервный вариант на случай, если современный COM-диалог недоступен
        # (сильно урезанная/нестандартная сборка Windows) — старый, но рабочий диалог.
        $fallback = New-Object System.Windows.Forms.FolderBrowserDialog
        $fallback.Description = $description
        $fallback.ShowNewFolderButton = $true
        if ((-not [string]::IsNullOrEmpty($initialPath)) -and (Test-Path $initialPath)) {
            $fallback.SelectedPath = $initialPath
        }
        $result = if ($form -ne $null) { $fallback.ShowDialog($form) } else { $fallback.ShowDialog() }
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            return $fallback.SelectedPath
        }
        return $null
    }
}

$global:installedSteamGames = @{}

# БАГ-ФИКС: сравнение "установлена ли игра" раньше шло точным совпадением строк
# (имя папки на диске == AppName ярлыка / == name или installdir из .acf).
# На практике это ломается сплошь и рядом: пользователь мог переименовать
# ярлык в самом Steam (AppName после этого больше не совпадает с папкой),
# Windows не разрешает символ ":" в именах папок (Steam заменяет его на "-"
# или просто убирает), в AppName может затесаться лишняя точка/пробел/суффикс
# и т.п. Из-за этого большинство реально установленных игр не подсвечивались.
#
# Решение: сравниваем не сырые строки, а их "нормализованную" форму — оставляем
# только буквы и цифры, убирая ВСЮ пунктуацию, пробелы и регистр. Так
# "Condemned: Criminal Origins PI Steam" и "Condemned - Criminal Origins"
# всё ещё не совпадут (разный текст), но "Chop Chop Inc." и "Chop Chop Inc"
# совпадут, как и "Bylina" / "BYLINA " и т.п. — все "технические" расхождения
# в форматировании имени перестают ломать сравнение.
function Get-NormalizedGameKey ($rawName) {
    if ([string]::IsNullOrEmpty($rawName)) { return "" }
    return [System.Text.RegularExpressions.Regex]::Replace($rawName.ToUpper(), '[^\p{L}\p{Nd}]', '')
}

# Тот же самый признак "в библиотеке", что рисует зелёную подпись-галочку у
# строки списка (см. Register-ListBoxDrawEvent) — используется колонкой
# сортировки "В библиотеке", чтобы сортировка совпадала с тем, что видно
# на экране.
function Test-PanelItemInLibrary ([string]$rawName) {
    $clean = Clean-GameName $rawName
    return [bool]$global:installedSteamGames.ContainsKey((Get-NormalizedGameKey $clean))
}

# ===================== НЕЧЁТКОЕ СРАВНЕНИЕ НАЗВАНИЙ ИГР =====================
# Слова, которые почти ничего не говорят о том, какая это ИМЕННО игра
# (обозначения изданий, ремастеров и т.п.) — исключаются при разбиении
# названия на "значимые" слова для нечёткого сравнения. Иначе почти любые
# две игры с "Complete Edition" в названии считались бы "похожими" друг
# на друга.
$global:steamStopWords = @('THE','A','AN','OF','AND','EDITION','EDITIONS','GOTY','COMPLETE','DEFINITIVE','REMASTERED','REMASTER','HD','ULTIMATE','DELUXE','GOLD','COLLECTORS','ENHANCED','DIRECTORS','CUT','REMAKE','REBIRTH','ANNIVERSARY','GAME','YEAR','SPECIAL','STANDARD','VERSION')

# Разбивает название на "значимые" слова (без пунктуации, торговых значков
# и служебных слов изданий) — используется для нечёткого сравнения
# результатов онлайн-поиска Steam.
function Get-NameTokens ($name) {
    if ([string]::IsNullOrEmpty($name)) { return @() }
    $clean = $name -replace '[™®©]', ''
    $words = [System.Text.RegularExpressions.Regex]::Split($clean.ToUpper(), '[^\p{L}\p{Nd}]+') | Where-Object { $_ -ne '' }
    return @($words | Where-Object { $global:steamStopWords -notcontains $_ })
}

# Доля общих значимых слов между двумя названиями (коэффициент Жаккара).
# 1.0 — идентичный набор слов, 0.0 — ничего общего.
function Get-TokenOverlapScore ($tokensA, $tokensB) {
    if ($tokensA.Count -eq 0 -or $tokensB.Count -eq 0) { return 0 }
    $setA = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($t in $tokensA) { [void]$setA.Add($t) }
    $setB = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($t in $tokensB) { [void]$setB.Add($t) }
    $common = 0
    foreach ($t in $setA) { if ($setB.Contains($t)) { $common++ } }
    $union = ([int]$setA.Count + [int]$setB.Count) - [int]$common
    if ($union -eq 0) { return 0 }
    return ($common / [double]$union)
}

# Некоторые игры (особенно на Unreal Engine) держат .exe в глубоко вложенной
# подпапке (например "ИмяИгры\ИмяИгры\Binaries\Win64\Game.exe"), и StartDir
# ярлыка указывает именно на эту вложенную папку, а не на корневую папку игры
# в SSD/HDD-панели. Раньше игра "угадывалась" по фиксированному номеру
# сегмента пути — ломалось при любой другой глубине вложенности. Эта функция
# решает задачу иначе и однозначно: раз мы точно знаем корень библиотеки
# (SSD-папку $global:dirC или HDD-папку $global:dirD), достаточно найти, какой
# из ПОДПАПОК этого корня является префиксом пути из ярлыка (Exe/StartDir) —
# именно он и есть настоящая папка игры, независимо от того, насколько глубоко
# внутри неё лежит сам .exe.
function Get-TopLevelFolderUnderRoot ($fullPath, $rootPath) {
    if ([string]::IsNullOrEmpty($fullPath) -or [string]::IsNullOrEmpty($rootPath)) { return $null }
    try {
        $normRoot = $rootPath.Trim('"').TrimEnd('\') + '\'
        $normPath = $fullPath.Trim('"')
        if ($normPath.Length -le $normRoot.Length) { return $null }
        if ($normPath.Substring(0, $normRoot.Length).ToUpper() -ne $normRoot.ToUpper()) { return $null }
        $rest = $normPath.Substring($normRoot.Length)
        $firstSegment = $rest.Split('\')[0]
        if ([string]::IsNullOrEmpty($firstSegment)) { return $null }
        return $firstSegment
    } catch { return $null }
}

function Register-ListBoxDrawEvent ($listBox) {
    $listBox.Add_DrawItem({
        param([object]$sender, [System.Windows.Forms.DrawItemEventArgs]$e)
        if ($e.Index -lt 0) { return }
        
        $itemText = $sender.Items[$e.Index].ToString()
        $cleanName = Clean-GameName $itemText
        $isInstalled = $global:installedSteamGames.ContainsKey((Get-NormalizedGameKey $cleanName))
        $src = [string]$sender.Tag
        $checkedSet = Get-CheckedSet $src
        $isChecked = $checkedSet.ContainsKey($cleanName)
        $isSelected = $e.State.HasFlag([System.Windows.Forms.DrawItemState]::Selected)
        
        if ($isSelected) {
            $rowBrush = New-Object System.Drawing.SolidBrush($steamUi.Selected)
            $e.Graphics.FillRectangle($rowBrush, $e.Bounds)
            $rowBrush.Dispose()
            $brush = New-Object System.Drawing.SolidBrush($steamUi.Text)
        } else {
            # Строки оформлены как в самом Steam: только едва заметное чередование
            # двух тёмных оттенков, одинаковое для всех строк вне зависимости от
            # статуса. Статус "в библиотеке" показывает исключительно зелёная
            # подпись-галочка в своей колонке — без изменения фона.
            $rowBg = if (($e.Index % 2) -eq 0) { $steamUi.Panel2 } else { $steamUi.Panel }
            $rowBrush = New-Object System.Drawing.SolidBrush($rowBg)
            $e.Graphics.FillRectangle($rowBrush, $e.Bounds)
            $rowBrush.Dispose()
            $brush = New-Object System.Drawing.SolidBrush($steamUi.Text)
        }

        # Галочка выбора для пакетных операций (перенос / добавление нескольких).
        # Отдельно от клика по самой строке — тот только выделяет строку, а не
        # открывает карточку (см. Invoke-GamePanelClick / Invoke-GamePanelDoubleClick).
        $cbRect = Get-RowCheckboxRect $e.Bounds
        if ($isChecked) {
            $cbBg = New-Object System.Drawing.SolidBrush($steamUi.Accent)
            $e.Graphics.FillRectangle($cbBg, $cbRect)
            $cbBg.Dispose()
            $checkPen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 1.6)
            $e.Graphics.DrawLine($checkPen, $cbRect.X + 3, $cbRect.Y + 7, $cbRect.X + 6, $cbRect.Y + 10)
            $e.Graphics.DrawLine($checkPen, $cbRect.X + 6, $cbRect.Y + 10, $cbRect.X + 11, $cbRect.Y + 3)
            $checkPen.Dispose()
        } else {
            $cbBorderColor = if ($isSelected) { [System.Drawing.Color]::White } else { $steamUi.Muted }
            $cbPen = New-Object System.Drawing.Pen($cbBorderColor, 1.2)
            $e.Graphics.DrawRectangle($cbPen, $cbRect)
            $cbPen.Dispose()
        }

        # ===== Колонки: Имя | Размер | Дата | В библиотеке =====
        # Границы берутся из $script:colWidths (их двигает пользователь мышкой в
        # заголовке — см. New-SortHeaderRow), поэтому каждое значение рисуется
        # строго в своей колонке и под своим заголовком. Текст в колонке обрезается
        # многоточием и никогда не залезает в соседнюю.
        $w = $script:colWidths[$src]
        if ($w -eq $null) { $w = @(238, 80, 85, 36) }
        $colX0 = $e.Bounds.X
        $colX1 = $colX0 + [int]$w[0]
        $colX2 = $colX1 + [int]$w[1]
        $colX3 = $colX2 + [int]$w[2]
        $sf = New-Object System.Drawing.StringFormat
        $sf.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter
        $sf.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap
        $mutedColor = if ($isSelected) { [System.Drawing.Color]::FromArgb(225,225,225) } else { $steamUi.Muted }

        # Имя (текст начинается правее галочки — на тех же 30 px, что и заголовок "Имя").
        $nameRect = New-Object System.Drawing.RectangleF(($colX0 + 30), ($e.Bounds.Y + 4), [Math]::Max(1, [int]$w[0] - 36), 21)
        $e.Graphics.DrawString($itemText, $e.Font, $brush, $nameRect, $sf)
        $brush.Dispose()

        $smallFont = New-Object System.Drawing.Font("Segoe UI", 8)

        # Размер — посчитанный размер папки (Пробел / Alt+Shift+Enter / сортировка
        # "по размеру" кладут результат в общий $global:folderSizeCache).
        $rootForSize = if ($src -eq 'C') { $global:dirC } else { $global:dirD }
        $pathForSize = if ([string]::IsNullOrWhiteSpace($rootForSize)) { $null } else { Join-Path $rootForSize $cleanName }
        $cachedSizeBytes = if ($pathForSize) { Get-FolderSizeCached $pathForSize } else { -1 }
        if ($cachedSizeBytes -ge 0) {
            # Меньше гигабайта показываем в мегабайтах (целым числом), от гигабайта — в ГБ.
            $sizeMb = [Math]::Round($cachedSizeBytes / 1MB, 0)
            if ($cachedSizeBytes -lt 1GB -and $sizeMb -lt 1024) {
                $sizeText = $sizeMb.ToString([System.Globalization.CultureInfo]::InvariantCulture) + " " + (T 'unit_mb')
            } else {
                $sizeText = ([Math]::Round($cachedSizeBytes / 1GB, 2)).ToString([System.Globalization.CultureInfo]::InvariantCulture) + " " + (T 'unit_gb')
            }
            $sizeBrush = New-Object System.Drawing.SolidBrush($mutedColor)
            $sizeRect = New-Object System.Drawing.RectangleF(($colX1 + 8), ($e.Bounds.Y + 5), [Math]::Max(1, [int]$w[1] - 12), 20)
            $e.Graphics.DrawString($sizeText, $smallFont, $sizeBrush, $sizeRect, $sf)
            $sizeBrush.Dispose()
        }

        # Дата — дата изменения папки (та же, по которой работает сортировка "Дата").
        $dateMap = if ($src -eq 'C') { $script:panelDateMapC } else { $script:panelDateMapD }
        if ($dateMap -ne $null -and $dateMap.ContainsKey($cleanName)) {
            $dateText = ([datetime]$dateMap[$cleanName]).ToString('dd.MM.yyyy', [System.Globalization.CultureInfo]::InvariantCulture)
            $dateBrush = New-Object System.Drawing.SolidBrush($mutedColor)
            $dateRect = New-Object System.Drawing.RectangleF(($colX2 + 8), ($e.Bounds.Y + 5), [Math]::Max(1, [int]$w[2] - 12), 20)
            $e.Graphics.DrawString($dateText, $smallFont, $dateBrush, $dateRect, $sf)
            $dateBrush.Dispose()
        }
        $smallFont.Dispose()

        # В библиотеке — зелёная подпись-галочка; видна и на выделенной строке
        # (на синем фоне берём чуть более яркий зелёный, чтобы не сливалась).
        if ($isInstalled) {
            $badgeFont = New-Object System.Drawing.Font("Segoe UI Semibold", 8)
            $badgeColor = if ($isSelected) { [System.Drawing.Color]::FromArgb(128,214,150) } else { $steamUi.Green }
            $badgeBrush = New-Object System.Drawing.SolidBrush($badgeColor)
            $badgeRect = New-Object System.Drawing.RectangleF(($colX3 + 8), ($e.Bounds.Y + 5), [Math]::Max(1, [int]$w[3] - 10), 20)
            $e.Graphics.DrawString("✓", $badgeFont, $badgeBrush, $badgeRect, $sf)
            $badgeBrush.Dispose()
            $badgeFont.Dispose()
        }
        $sf.Dispose()
        $e.DrawFocusRectangle()
    })
}
function Get-SteamShortcutID ($exePath, $gameName) {
    $inputString = "`"$exePath`"$gameName"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($inputString)

    # ВАЖНО: PowerShell парсит 8-значные HEX-литералы (0xffffffff, 0xedb88320,
    # 0x80000000) как ЗНАКОВЫЙ Int32 — например 0xffffffff превращается в -1,
    # а не в 4294967295. А оператор -shr на отрицательных (знаковых) числах
    # делает АРИФМЕТИЧЕСКИЙ сдвиг (протягивает единицы слева), а не логический
    # (заполнение нулями), который нужен для правильного CRC32. Из-за этого
    # расчёт "портился" знаковым битом, и на выходе иногда получалось
    # отрицательное число — которое затем не мог принять [uint32] при вызове
    # этой функции, и добавление ярлыка падало с ошибкой преобразования типа.
    # Фикс: работаем строго в типе [uint32] (для него -shr гарантированно
    # логический), а константы, которые как HEX стали бы отрицательными,
    # задаём десятичным числом — так они парсятся как положительные и не
    # "переинтерпретируются" в 32-битный знаковый вид.
    [uint32]$allOnes = 4294967295          # было бы 0xffffffff
    [uint32]$poly    = 3988292384          # было бы 0xedb88320
    [uint32]$topBit  = 2147483648          # было бы 0x80000000

    [uint32]$crc = $allOnes
    foreach ($b in $bytes) {
        $crc = $crc -bxor [uint32]$b
        for ($i = 0; $i -lt 8; $i++) {
            if (($crc -band 1) -ne 0) { $crc = ($crc -shr 1) -bxor $poly } else { $crc = $crc -shr 1 }
        }
    }
    [uint32]$hash = $crc -bxor $allOnes

    # Именно это 32-битное число Steam использует как ID для файлов обложек в config\grid\
    [uint32]$topPart = $hash -bor $topBit
    return [string]$topPart
}
# ===================== НАСТОЯЩИЙ ПАРСЕР БИНАРНОГО VDF =====================
# Раньше вставка новой записи в shortcuts.vdf делалась "на глаз": просто
# отрезались последние 1-2 байта 0x08 в конце файла, а поиск свободного
# индекса делался сканированием ВСЕХ байт файла на "похоже на цифры между
# нулями". Это работало только пока хвост файла случайно совпадал с
# предположением автора. Стоило структуре отличаться (другой набор полей
# у существующих ярлыков, файл уже был чуть повреждён предыдущим запуском
# и т.п.) — вставка попадала не в то место, файл ломался, и Steam либо не
# видел новый ярлык, либо падал при чтении битого shortcuts.vdf.
#
# Вместо этого здесь честно разбирается вложенность объектов VDF
# (тип 0x00 = вложенный объект, 0x01 = строка, 0x02 = int32, 0x08 = конец
# объекта) и новая запись вставляется РОВНО перед байтом 0x08, закрывающим
# объект "shortcuts" — независимо от того, что и как записано у уже
# существующих ярлыков.
function Read-VdfObjectBody ($bytes, $pos) {
    $children = New-Object System.Collections.Generic.List[object]
    while ($true) {
        if ($pos -ge $bytes.Length) { throw (T 'vdf_eof') }
        $type = $bytes[$pos]
        if ($type -eq 0x08) {
            return [PSCustomObject]@{ Children = $children; EndPos = $pos; NextPos = ($pos + 1) }
        }
        $pos++
        $keyStart = $pos
        while ($pos -lt $bytes.Length -and $bytes[$pos] -ne 0x00) { $pos++ }
        if ($pos -ge $bytes.Length) { throw (T 'vdf_eof_key') }
        $key = [System.Text.Encoding]::UTF8.GetString($bytes, $keyStart, $pos - $keyStart)
        $pos++
        switch ($type) {
            0x00 {
                $sub = Read-VdfObjectBody $bytes $pos
                $children.Add([PSCustomObject]@{ Key = $key; Type = 0x00; Body = $sub })
                $pos = $sub.NextPos
            }
            0x01 {
                $valStart = $pos
                while ($pos -lt $bytes.Length -and $bytes[$pos] -ne 0x00) { $pos++ }
                if ($pos -ge $bytes.Length) { throw (T 'vdf_eof_str') }
                $val = [System.Text.Encoding]::UTF8.GetString($bytes, $valStart, $pos - $valStart)
                $pos++
                $children.Add([PSCustomObject]@{ Key = $key; Type = 0x01; Value = $val })
            }
            0x02 {
                if ($pos + 4 -gt $bytes.Length) { throw (T 'vdf_eof_int') }
                $val = [BitConverter]::ToUInt32($bytes, $pos)
                $pos += 4
                $children.Add([PSCustomObject]@{ Key = $key; Type = 0x02; Value = $val })
            }
            default { throw (T 'vdf_bad_field' @($type.ToString('X2'), $pos)) }
        }
    }
}

# Находит объект "shortcuts" внутри разобранного корня файла.
function Get-ShortcutsNode ($bytes) {
    $root = Read-VdfObjectBody $bytes 0
    return ($root.Children | Where-Object { $_.Key -eq "shortcuts" } | Select-Object -First 1)
}

$global:exeDir = [System.AppDomain]::CurrentDomain.BaseDirectory
# Конфигурация пользователя — в %APPDATA%, а не рядом с EXE.
$global:configPath = Join-Path $global:appDataDir "config.ini"

# Папка для резервных копий shortcuts.vdf. Пусто = папка "backups" рядом
# с программой (значение по умолчанию); пользователь может выбрать свою
# папку через кнопку «Обзор» в настройках.
$global:backupFolderPath = ""

function Get-BackupFolderPath {
    if (-not [string]::IsNullOrWhiteSpace([string]$global:backupFolderPath)) {
        return [string]$global:backupFolderPath
    }
    return (Join-Path $global:exeDir "backups")
}

# Настройки Steam: путь установки и конкретный профиль userdata.
$global:steamInstallPath = ""
$global:steamUserId = ""

function Get-DefaultSteamInstallPath {
    try {
        $steamPath = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamPath" -ErrorAction SilentlyContinue).SteamPath
        if (-not [string]::IsNullOrWhiteSpace([string]$steamPath) -and (Test-Path -LiteralPath [string]$steamPath)) {
            return [System.IO.Path]::GetFullPath([string]$steamPath)
        }
    } catch {}
    try {
        $steamExe = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamExe" -ErrorAction SilentlyContinue).SteamExe
        if (-not [string]::IsNullOrWhiteSpace([string]$steamExe)) {
            $steamDir = [System.IO.Path]::GetDirectoryName([string]$steamExe)
            if (-not [string]::IsNullOrWhiteSpace($steamDir)) { return [System.IO.Path]::GetFullPath($steamDir) }
        }
    } catch {}
    return "C:\Program Files (x86)\Steam"
}

function Get-ConfiguredSteamInstallPath {
    try {
        if (-not [string]::IsNullOrWhiteSpace([string]$global:steamInstallPath)) {
            return [System.IO.Path]::GetFullPath([string]$global:steamInstallPath)
        }
    } catch {}
    return Get-DefaultSteamInstallPath
}

function Get-ConfiguredSteamExePath {
    try {
        $root = Get-ConfiguredSteamInstallPath
        $candidate = Join-Path $root 'steam.exe'
        if (Test-Path -LiteralPath $candidate) { return [string]$candidate }
    } catch {}
    return 'steam.exe'
}

function Get-ConfiguredSteamUserDataPath {
    $root = Get-ConfiguredSteamInstallPath
    $userDataRoot = Join-Path $root 'userdata'
    try {
        $userId = [string]$global:steamUserId
        if (-not [string]::IsNullOrWhiteSpace($userId) -and $userId -match '^\d+$') {
            $profilePath = Join-Path $userDataRoot $userId
            if (Test-Path -LiteralPath $profilePath) { return [string]$profilePath }
        }
    } catch {}
    return [string]$userDataRoot
}

function Get-ConfiguredSteamProfileDirectories {
    try {
        $userDataRoot = Join-Path (Get-ConfiguredSteamInstallPath) 'userdata'
        if (-not (Test-Path -LiteralPath $userDataRoot)) { return @() }

        $userId = [string]$global:steamUserId
        if (-not [string]::IsNullOrWhiteSpace($userId) -and $userId -match '^\d+$') {
            $selected = Join-Path $userDataRoot $userId
            if (Test-Path -LiteralPath $selected) {
                return @([System.IO.DirectoryInfo]$selected)
            }
            return @()
        }

        return @(Get-ChildItem -LiteralPath $userDataRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d+$' })
    } catch {
        return @()
    }
}

function Get-SteamUserProfiles {
    $result = New-Object System.Collections.ArrayList
    try {
        $steamRoot = Get-ConfiguredSteamInstallPath
        $userDataRoot = Join-Path $steamRoot 'userdata'
        if (-not (Test-Path -LiteralPath $userDataRoot)) { return @($result) }

        $loginUsersPath = Join-Path $steamRoot 'config\loginusers.vdf'
        $loginText = ""
        try {
            if (Test-Path -LiteralPath $loginUsersPath) {
                $loginText = Get-Content -LiteralPath $loginUsersPath -Raw -ErrorAction SilentlyContinue
            }
        } catch {}

        foreach ($dir in @(Get-ChildItem -LiteralPath $userDataRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d+$' })) {
            $id = [string]$dir.Name
            $persona = ""
            $account = ""
            $mostRecent = $false

            if (-not [string]::IsNullOrWhiteSpace($loginText)) {
                try {
                    $escapedId = [regex]::Escape($id)
                    $startMatch = [regex]::Match($loginText, '"' + $escapedId + '"\s*\{')
                    if ($startMatch.Success) {
                        $tail = $loginText.Substring($startMatch.Index)
                        $block = $tail.Substring(0, [Math]::Min(5000, $tail.Length))
                        $pm = [regex]::Match($block, '"PersonaName"\s*"([^"]*)"')
                        if ($pm.Success) { $persona = [string]$pm.Groups[1].Value }
                        $am = [regex]::Match($block, '"AccountName"\s*"([^"]*)"')
                        if ($am.Success) { $account = [string]$am.Groups[1].Value }
                        if ($block -match '"MostRecent"\s*"1"') { $mostRecent = $true }
                    }
                } catch {}
            }

            $displayName = $id
            if (-not [string]::IsNullOrWhiteSpace($persona)) {
                $displayName = $persona + "  [" + $id + "]"
            } elseif (-not [string]::IsNullOrWhiteSpace($account)) {
                $displayName = $account + "  [" + $id + "]"
            }

            [void]$result.Add([PSCustomObject]@{
                Id = $id
                Name = $persona
                AccountName = $account
                DisplayName = $displayName
                Directory = $dir
                MostRecent = $mostRecent
            })
        }

        return @($result | Sort-Object @{Expression='MostRecent';Descending=$true}, @{Expression='DisplayName';Descending=$false})
    } catch {
        return @($result)
    }
}

function Load-Configuration {
    if (Test-Path $global:configPath) {
        try {
            $lines = Get-Content $global:configPath -ErrorAction SilentlyContinue
            foreach ($line in $lines) {
                if ($line.StartsWith("dirC=")) { $global:dirC = $line.Substring(5).Trim() }
                if ($line.StartsWith("dirD=")) { $global:dirD = $line.Substring(5).Trim() }
                if ($line.StartsWith("steamInstallPath=")) { $global:steamInstallPath = $line.Substring(17).Trim() }
                if ($line.StartsWith("steamUserId=")) { $global:steamUserId = $line.Substring(12).Trim() }
                # БАГ-ФИКС: "steamGridDbApiKey=" — это РОВНО 18 символов, а здесь
                # стоял Substring(19) — при каждой загрузке config.ini у ключа
                # обрезался первый символ, ключ становился невалидным, и
                # SteamGridDB закономерно отвечал 401 Unauthorized даже с
                # правильно введённым и сохранённым ключом.
                if ($line.StartsWith("steamGridDbApiKey=")) { $global:steamGridDbApiKey = $line.Substring(18).Trim() }
                if ($line.StartsWith("backupFolderPath=")) { $global:backupFolderPath = $line.Substring(17).Trim() }
                if ($line.StartsWith("language=")) { $global:language = $line.Substring(9).Trim() }
            }
        } catch {}
    }
}
Load-Configuration
# Язык не выбран (первый запуск) или в config.ini неизвестное значение — берём язык
# интерфейса Windows, если он есть в таблице, иначе английский.
if (-not $script:I18n.ContainsKey([string]$global:language)) {
    $uiLang = 'en'
    try { $uiLang = [System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName } catch {}
    $global:language = if ($script:I18n.ContainsKey($uiLang)) { $uiLang } else { 'en' }
}

# Результат проверки ключа SteamGridDB: не просто "да/нет", а причина, которую
# можно показать пользователю (см. подпись под полем ключа в «Настройках»).
#   Kind     — valid | invalid | forbidden | ratelimit | server | network | other | empty
#   Severity — ok | error | warn | none  (warn = ключ не признан плохим, сервис
#              просто не смог ответить; error = проблема с ключом или доступом)
# Текст сообщения НЕ запоминается готовой строкой: хранится ключ перевода и его
# аргументы, а Message вычисляется через T при каждом обращении. Поэтому после
# смены языка подпись под полем ключа переводится сразу, без перезапуска.
function New-SgdbKeyCheckResult($valid, [string]$kind, [string]$severity, [int]$status, [string]$msgKey, [object[]]$msgArgs = @()) {
    $res = [PSCustomObject]@{
        Valid        = [bool]$valid
        Kind         = $kind
        Severity     = $severity
        StatusCode   = $status
        MsgKey       = $msgKey
        MsgArgs      = @($msgArgs)
        NetworkError = ($kind -eq 'network' -or $kind -eq 'server' -or $kind -eq 'ratelimit')
    }
    Add-Member -InputObject $res -MemberType ScriptProperty -Name Message -Value { T ([string]$this.MsgKey) ([object[]]$this.MsgArgs) }
    return $res
}

function Get-SgdbKeyCheckResult([string]$apiKey) {
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        return (New-SgdbKeyCheckResult $false 'empty' 'none' 0 'key_empty')
    }
    # Эта проверка выполняется при запуске, раньше остальных сетевых вызовов,
    # поэтому TLS 1.2 включаем здесь явно (в Windows PowerShell 5.1 он по
    # умолчанию бывает выключен).
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

    try {
        $headers = @{ Authorization = "Bearer $($apiKey.Trim())" }
        $url = 'https://www.steamgriddb.com/api/v2/search/autocomplete/__steam_commander_key_check__'
        Invoke-RestMethod -Uri $url -Headers $headers -TimeoutSec 10 -ErrorAction Stop | Out-Null
        return (New-SgdbKeyCheckResult $true 'valid' 'ok' 200 'key_valid')
    } catch {
        $ex = $_.Exception
        $statusCode = 0
        try { $statusCode = [int]$ex.Response.StatusCode.value__ } catch {}
        $webStatus = ''
        try { $webStatus = [string]$ex.Status } catch {}
        $rawMsg = ''
        try { $rawMsg = [string]$ex.Message } catch {}

        if ($statusCode -eq 401) { return (New-SgdbKeyCheckResult $false 'invalid' 'error' 401 'sg_401') }
        if ($statusCode -eq 403) { return (New-SgdbKeyCheckResult $false 'forbidden' 'error' 403 'sg_403') }
        if ($statusCode -eq 429) { return (New-SgdbKeyCheckResult $false 'ratelimit' 'warn' 429 'sg_429') }
        if ($statusCode -ge 500) { return (New-SgdbKeyCheckResult $false 'server' 'warn' $statusCode 'sg_server' @($statusCode)) }
        if ($statusCode -gt 0)   { return (New-SgdbKeyCheckResult $false 'other' 'error' $statusCode 'sg_other' @($statusCode)) }

        # Ответа от сервера нет вовсе — уточняем причину по типу сетевой ошибки.
        $msgArgs = @()
        if ($webStatus -match 'NameResolutionFailure') {
            $msg = 'sg_dns'
        } elseif ($webStatus -eq 'Timeout') {
            $msg = 'sg_timeout'
        } elseif ($webStatus -match 'SecureChannelFailure|TrustFailure' -or $rawMsg -match 'SSL/TLS') {
            $msg = 'sg_tls'
        } elseif ($webStatus -match 'ConnectFailure|ConnectionClosed|SendFailure|ReceiveFailure') {
            $msg = 'sg_connect'
        } else {
            if ($rawMsg.Length -gt 100) { $rawMsg = $rawMsg.Substring(0, 100) + '…' }
            $msg = 'sg_noresp'; $msgArgs = @($rawMsg)
        }
        return (New-SgdbKeyCheckResult $false 'network' 'warn' 0 $msg $msgArgs)
    }
}

# При запуске сразу проверяем сохранённый ключ SteamGridDB. Это важно для карточек
# игр: они создаются раньше, чем пользователь вообще может открыть «Настройки»,
# поэтому состояние переключателя SGDB должно быть известно уже при старте.
# Если ключ пустой, недействительный или API недоступен — SGDB считается
# недоступным. При успешном HTTP-ответе флаг становится true.
function Initialize-SteamGridDbApiKeyValidation {
    $apiKey = [string]$global:steamGridDbApiKey
    $global:steamGridDbApiKeyValid = $false
    $global:steamGridDbApiKeyCheck = $null

    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        return $false
    }

    # Любая неудача = SGDB выключен, но причина (401, сервис недоступен, TLS и
    # т.д.) теперь запоминается и показывается в «Настройках» под полем ключа.
    $check = Get-SgdbKeyCheckResult $apiKey
    $global:steamGridDbApiKeyCheck = $check
    $global:steamGridDbApiKeyValid = [bool]$check.Valid
    return [bool]$check.Valid
}

# Проверка выполняется один раз при старте программы, сразу после чтения config.ini.
# Поэтому карточка игры получает правильное состояние кнопки SGDB без захода в настройки.
Initialize-SteamGridDbApiKeyValidation | Out-Null

if ([string]::IsNullOrWhiteSpace([string]$global:steamInstallPath)) {
    $global:steamInstallPath = Get-DefaultSteamInstallPath
}
if ([string]::IsNullOrWhiteSpace([string]$global:steamUserId)) {
    try {
        $firstProfile = @(Get-SteamUserProfiles) | Select-Object -First 1
        if ($firstProfile -ne $null) {
            $global:steamUserId = [string]$firstProfile.Id
        }
    } catch {}
}

$steamUi = [ordered]@{
    Bg = [System.Drawing.Color]::FromArgb(23,29,37)
    Panel = [System.Drawing.Color]::FromArgb(27,40,56)
    Panel2 = [System.Drawing.Color]::FromArgb(20,30,42)
    Input = [System.Drawing.Color]::FromArgb(13,20,28)
    Border = [System.Drawing.Color]::FromArgb(58,73,90)
    Text = [System.Drawing.Color]::FromArgb(220,223,228)
    Muted = [System.Drawing.Color]::FromArgb(145,154,164)
    Accent = [System.Drawing.Color]::FromArgb(102,192,244)
    Accent2 = [System.Drawing.Color]::FromArgb(26,159,255)
    Selected = [System.Drawing.Color]::FromArgb(38,76,108)
    Green = [System.Drawing.Color]::FromArgb(92,173,112)
}

# Серый текст-подсказка внутри TextBox ("Поиск…"), пока поле пустое и не в
# фокусе — стандартного свойства Placeholder у WinForms TextBox нет, поэтому
# нативное сообщение EM_SETCUEBANNER (тот же приём P/Invoke, что и у
# ListBoxCaretNative дальше в этом файле).
try {
    if (-not ('TextBoxCueBanner' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class TextBoxCueBanner {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, string lParam);
    private const int EM_SETCUEBANNER = 0x1501;
    public static void SetCue(IntPtr hWnd, string text) {
        SendMessage(hWnd, EM_SETCUEBANNER, IntPtr.Zero, text);
    }
}
'@
    }
} catch {}
function Set-TextBoxCue ($textBox, [string]$text) {
    try { [TextBoxCueBanner]::SetCue($textBox.Handle, $text) } catch {}
}

# ===================== ИКОНКА ПРИЛОЖЕНИЯ =====================
# ICO (16/20/24/32/40/48 px, несжатые BMP-кадры) встроен как Base64, чтобы
# значок был и при запуске из .ps1, и внутри собранного EXE. WinForms сам
# выбирает нужный кадр под текущий масштаб экрана.
$global:embeddedAppIconIco = "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Hf+pYRv/um8k/39cOv8zKCP/RDQq/2JQRUZiUEVGRDMq/zsvKf+kcDv/tWgd/65mH/+qZyD/nFES/3JMG/8vkmf/DMOZ/2J3Qv+pWBT/lFQS/49QEP+EQwP/lm5H/9bKvv/QwLL/0cK0/9HCtP/QwLL/18vA/5lzTf+DQgL/kFAR/5NTEv+oWBT/ZnM+/wzCmP8ulGr/cU0c/5xQEv+qZiD/rmYf/7VoHf+jcDv/Oy8p/0QzKv9iUEVGZlNFRkEyKf9MPDD/uHg2/7BpHv+pYx7/kkkP/1ZlOP8asof/E8WZ/w7Hnf9ThFH/lEsS/5FyTv+Vdlb/jW1M/6aOdv/Wybv/0cO0/9LEtf/SxLX/0cO0/9fJvP+okXr/jGxM/5V1Vv+Sck//k0sT/1ODUP8Ox53/E8WZ/xqzif9UZjn/kUgP/6hiHf+waR7/uHg2/0w8MP9BMin/ZlNFRmlTRUY/MCn/YEk1/716Mv+iVhP/f0wY/ziIXf8RxZv/FcSY/xm8kP8PyqD/TnlE/69+W//b1cz/2czA/9rOwv/Yy77/08S2/9PFt//Txbf/08W3/9PFt//SxLb/2Mu9/9rPwv/ZzMD/29XM/7KCYf9NeET/D8qg/xm8kf8VxJj/EMab/zeKX/99TRn/olUT/7x6Mf9gSTX/PzAp/2lTRUZtV0hGPjAq/2xTOf+xZyP/Y10s/yCrgv8Qy6D/F8GV/xfAlf8YwJT/D8uh/056Rv+9kXP/1s/D/9LCs//SxLX/08W2/9TGuP/Uxrj/1Ma4/9TGuP/Uxrj/1Ma4/9PFtv/SxLX/0sKz/9bOwv+/lXn/TXpG/w/Lof8YwJT/F8CV/xfAlf8Qy6D/H62D/2FeLv+wZiL/bFM5/z4wKv9tV0hGbVdIRj0yLf97UTP/fodK/wrDm/8Wx5v/GMGV/xbDmP8Ww5j/GMGW/w/No/9PfEf/vI9w/9jRxv/Uxbf/1ce5/9XHuf/Vx7n/1ce5/9XHuf/Vx7n/1ce5/9XHuf/Vx7n/1ce5/9TFt//Y0MX/vpN2/058SP8PzaP/GMGW/xbDmP8Ww5j/GMGV/xfHm/8KxZz/eYlO/3tQMv89My3/bVdIRnBbSEY+My3/f1Q1/5SRTf8Pw5r/Esed/xrDl/8XxJn/F8SZ/xnCl/8QzqX/UX1I/76Rcf/Z08j/1ce5/9bJu//Wybv/1sm7/9bJu//Wybv/1sm7/9bJu//Wybv/1sm7/9bJu//Vx7n/2dLH/8CVd/9QfUn/EM6k/xnCl/8XxJn/F8SZ/xrDl/8Sx53/DsSb/46UUf9/VDX/PjMt/3BbSEZwW0hGQjMt/3FXPP/RfSv/mXo0/zO0hP8LzKT/GMWa/xnFmv8ZxJn/EM+n/1SASf/Dlnf/2tLI/9bHuP/Xybr/1sm7/9fKvP/Xyrz/18q8/9fKvP/Xyrz/18q8/9bJu//Xybr/1se4/9rSx//Fmn3/U4BK/xDPpv8ZxJn/GMWa/xjFmv8LzKT/MbWG/5d7Nf/RfSv/cVc8/0IzLf9wW0hGbVdIRkU2Lv9mTjn/y4c4/8dyHv+9cyT/YJ5k/xDKof8SyqD/HMSY/w/Qp/9chUv/xY1h/9rX0f/Zz8X/2tHI/9rPxP/Yy73/2Mu+/9jLvf/Yy73/2Mu+/9jLvf/az8T/2tHI/9nPxf/a19H/xpFn/1uFTP8P0Kf/HMSY/xPKoP8QyqH/XZ9m/7x0Jf/Hch7/y4c4/2ZOOf9FNi7/bVdIRm1XSEZKOS//VEI2/8aGPP/Eeyb/xXwp/81zHv+RiUP/KL6Q/w7NpP8M0Kj/YJRb/8VuHv/Fk1f/yJdg/8GOVf+/oH3/29DF/9jMvv/ZzL//2cy//9jLvv/b0cb/waOB/8COVf/Il2D/xZRZ/8VvH/9hk1r/DNCo/w/MpP8mv5H/j4pF/81zHv/GfCj/xHsm/8aGPP9UQjb/Sjkv/21XSEZpV0hGTz0y/0U3Mf+zfkL/zoEo/8Z9Kf/FgCv/0Hki/7p7K/9Sq3P/D82l/4ORT//PdyH/xHoh/8h6Iv+7bRL/tIdU/93Uy//ZzL7/2s7A/9rOwP/ZzL7/3dXM/7WKWf+6bBL/yHoi/8R6If/PeCH/iY5K/xDNpP9OrHb/uHss/9B4Iv/FgCv/xn0p/86BKP+zfkL/RTcx/089Mv9pV0hGbVdIRlE/M/9AMy3/jmlD/9eLMf/Hfin/yoAq/8iCLP/Ofyj/zHsm/7KGN//Kfij/yoAq/8uBLP/MhC//wngh/7uQX//d1Mr/2sy9/9vNv//bzb//2sy9/97Uy/+8lGX/wXcg/82EL//LgSz/yoEr/8t+KP+yhjf/y3wn/89/J//Igiz/yoAq/8d+Kf/XizH/jmlD/0AzLf9RPzP/bVdIRm1XSEZRPzT/Rzcv/2FMO//Tjz7/zIEo/82DLP/Ngyv/zIMs/82ELP/SgSj/zYMs/82DK//Ngyv/zoQt/8l8Iv/Eklf/3tnU/97VzP/e1s3/3tbN/93VzP/f2tb/xZVd/8h7If/OhC7/zYMr/82DK//Ngyz/0oEo/82DLP/Mgyz/zYMr/82DLP/MgSj/048+/2FMO/9HNy//UT80/21XSEZtV0xGUUA1/1A9Mv9FNzL/rHxH/9qMLv/NhCz/0IUs/9CFLP/PhS3/z4Yt/9CFLf/QhSz/0IUt/9CFLf/QhSz/y4Mt/9Gmc//Us4z/07GI/9OxiP/Us4z/0ad2/8uDLv/QhSz/0IUt/9CFLf/QhSz/0IUt/8+GLf/PhS3/0IUs/9CFLP/NhCz/2owu/6x8R/9FNzL/UD0y/1FANf9tV0xGbVtMRlJBNf9QPjP/Sjkx/2hRPv/alUH/0YUq/9KIL//SiC7/0ogu/9KILv/SiC7/0ogu/9KILv/SiC7/0ogu/9OILf/QgiP/z4Ej/8+BI//PgSP/z4Ej/9CCI//Thy3/04gu/9KILv/SiC7/0ogu/9KILv/SiC7/0ogu/9KILv/SiC//0YUq/9qVQf9oUT7/Sjkx/1A+M/9SQTX/bVtMRm1bTEZUQjb/UD4z/1NANf9GNzL/nHVI/+OWNv/Rhy3/1osv/9WKL//Viy//1Ysv/9WLL//Viy//1Ysv/9WKL//Viy//1owx/9aMMf/WjDH/1owx/9aMMf/WjDH/1Ysv/9WKL//Viy//1Ysv/9WLL//Viy//1Ysv/9WKL//Wiy//0Yct/+OWNv+cdUj/Rjcy/1NANf9QPjP/VEI2/21bTEZvWUtHVUM3/1E/NP9SQDX/Uj80/1BAOP/DjEv/4ZIw/9WLL//YjTD/2I0w/9iNMP/YjTD/2I0w/9iNMP/YjTD/2I0w/9iNMP/YjTD/2I0w/9iNMP/YjTD/2I0w/9iNMP/YjTD/2I0w/9iNMP/YjTD/2I0w/9iNMP/YjTD/1Ysv/+GSMP/DjEv/UEA4/1I/NP9SQDX/UT80/1VDN/9vWUtHdV1QP1ZDOP9SQDb/U0E2/1RCNv9PPTT/YEw9/9WXSv/hkzD/140x/9uQMv/bkDH/25Ax/9uQMf/bkDH/25Ax/9uQMf/bkDH/25Ax/9uQMf/bkDH/25Ax/9uQMf/bkDH/25Ax/9uQMf/bkDH/25Ax/9uQ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J/+wdjP/1ce4/9zQw//bz8D/287B/9vOwf/bzsH/3M/C/9fKvP+xeDf/xnsm/8uBLP/KgCv/yoAq/8t/Kf/HfSn/rIg6/8p7Jv/Ofif/yIIs/8qAKv/KgCr/yX8q/9GDKv+5hEf/Rzky/kw7MP9QQDTzhnJdJoZyXSZRQDXzTz0x/0I0Lv6Makb/25A2/8l/KP/Mgiv/zIIr/8yCK//Lgyz/zIMs/9OAJ//Ngiv/zIIr/8yCK//Mgiv/zIMs/8t/J/+7fDP/2My//93Sxv/c0ML/3NDD/9zQw//c0ML/3dHE/9rPw/+7fzj/yn4m/82DLP/Mgiv/zIIr/8yCK//Ngiv/04An/8yDLP/Lgyz/zYIr/8yCK//Mgiv/yX8o/9uQNv+Makb/QjQu/k89Mf9RQDXzhnJdJoZyXSZSQDXzTj0y/0s6MP5ZRzn/0pJH/8+DKf/OhC3/z4Qs/8+ELP/PhCz/zoQs/82FLf/OhCz/z4Qs/8+ELP/PhCz/z4Qs/8+FLf/GfSb/0a+H/93Tyf/c0MP/3NDE/9zQxP/c0MP/3dPJ/9Kyjf/GfSf/z4Qt/8+ELP/PhCz/z4Qs/8+ELP/OhCz/zYUt/86ELP/PhCz/z4Qs/8+ELP/OhC3/z4Mp/9KSR/9ZRzn/Szow/k49Mv9SQDXzhnJdJoZyXSZTQTbzTz0z/1E/M/5ENTD/nnZK/9+SNf/Ngyv/0YYt/9GGLf/Rhi3/0YYt/9GGLf/Rhi3/0YYt/9GGLf/Rhi3/0YYt/9GHLf/QhSz/zIIq/82OQ//Mj0X/zI5F/8yORf/Mj0X/zY5D/8yCKv/QhSv/0Yct/9GGLf/Rhi3/0YYt/9GGLf/Rhi3/0YYt/9GGLf/Rhi3/0YYt/9GGLf/Ngyv/35I1/552Sv9ENTD/UT8z/k89M/9TQTbzhnJdJoZyXSZVQjbzUD4z/1A+NP5NPDL/WUY6/9OWSv/ViCv/0ogv/9OJLv/TiS7/04ku/9OJLv/TiS7/04ku/9OJLv/TiS7/04ku/9OJLv/TiS7/1Ikv/9OGKf/Thij/04Yo/9OGKP/Thij/04Yp/9SJLv/TiS7/04ku/9OJLv/TiS7/04ku/9OJLv/TiS7/04ku/9OJLv/TiS7/04ku/9KIL//ViCv/05ZK/1lGOv9NPDL/UD40/lA+M/9VQjbzhnJdJoZyXSZWQzfzUT80/1E/NP5TQTX/Rzcw/4dnR//lm0D/0ocr/9aLMP/Viy//1Ysv/9WLL//Viy//1Ysv/9WLL//Viy//1Ysv/9WLL//Viy//1Ysv/9aLMP/WizD/1osw/9aLMP/WizD/1osw/9WLL//Viy//1Ysv/9WLL//Viy//1Ysv/9WLL//Viy//1Ysv/9WLL//Viy//1osw/9KHK//lm0D/h2dH/0c3MP9TQTX/UT80/lE/NP9WQzfzhnJdJoZyXSZXRDjzUkA1/1JANf5SQDX/U0E1/0k6NP+wg07/5Zg3/9SJLv/YjTH/2I0w/9iNMP/YjTD/2I0w/9iNMP/YjTD/2I0w/9iNMP/YjTD/2I0w/9iNMP/YjTD/2I0w/9iNMP/YjTD/2I0w/9iNMP/YjTD/2I0w/9iNMP/YjTD/2I0w/9iNMP/YjTD/2I0w/9iNMP/YjTH/1Iku/+WYN/+wg07/STo0/1NBNf9SQDX/UkA1/lJANf9XRDjzhnJdJoZxYyRXRDnxU0A2/1NBNv5TQTb/U0E2/1E/NP9UQzn/yZNQ/+SWM//WjC//2pAy/9qPMf/ajzH/2o8x/9qPMf/ajzH/2o8x/9qPMf/ajzH/2o8x/9qPMf/ajzH/2o8x/9qPMf/ajzH/2o8x/9qPMf/ajzH/2o8x/9qPMf/ajzH/2o8x/9qPMf/ajzH/2o8x/9qQMv/WjC//5JYz/8mTUP9UQzn/UT80/1NBNv9TQTb/U0E2/lNANv9XRDnxhnFjJL+fjxBaRzzhVUI3/1RBNv5UQTb/VEE2/1VDN/9QPjT/XUo9/9GYUf/mmDT/2I0w/9ySM//ckTL/3JEy/9yRMv/ckTL/3JEy/9yRMv/ckTL/3JEy/9yRMv/ckTL/3JEy/9yRMv/ckTL/3JEy/9yRMv/ckTL/3JEy/9yRMv/ckTL/3JEy/9yRMv/ckTL/3JIz/9iNMP/mmDT/0ZhR/11KPf9QPjT/VUM3/1RBNv9UQTb/VEE2/lVCN/9aRzzhv5+PEAICAQBgTUC5WEU5/lVCN/xVQjf/VUI3/1VCN/9XRDj/Tz40/15LPf/MlVH/7J45/9uPL//dkzT/35Qz/96TM//ekzP/3pMz/96TM//ekzP/3pMz/96TM//ekzP/3pMz/96TM//ekzP/3pMz/96TM//ekzP/3pMz/96TM//ekzP/3pMz/9+UM//dkzT/248v/+yeOf/MlVH/Xks9/08+NP9XRDj/VUI3/1VCN/9VQjf/VUI3/FhFOf5gTUC5AgIBAAAAAABsWEpuXEg8/1ZCN/xWQzj/VkM4/1ZDOP9WQzj/WEU5/1FANv9XRTv/tYdR/++lRP/jljH/3ZIy/+CVNf/hljT/4ZU0/+GVNP/hlTT/4ZU0/+GVNP/hlTT/4ZU0/+GVNP/hlTT/4ZU0/+GVNP/hlTT/4ZU0/+GVNP/hljT/4JU1/92SMv/jljH/76VE/7WHUf9XRTv/UUA2/1hFOf9WQzj/VkM4/1ZDOP9WQzj/VkI3/FxIPP9sWEpuAAAAAAAAAACdhW0VXUk961dEOf1XRDn9V0Q5/1dEOf9XRDn/V0Q5/1lFOf9WQzf/Tj43/4xsS//en0//8KM9/+SXMv/glTP/4Zc1/+OYNv/jmDX/45g1/+OYNf/jmDX/45g1/+OYNf/jmDX/45g1/+OYNf/jmDX/45g2/+GXNf/glTP/5Jcy//CjPf/en0//jGxL/04+N/9WQzf/WUU5/1dEOf9XRDn/V0Q5/1dEOf9XRDn9V0Q5/V1JPeudhW0VAAAAAFVVVQMAAAAAcVtMal9KPv9XRDn6WEU5/1hFOf9YRTn/WEU5/1hFOf9ZRTr/WkY5/049Nv9gTUD/p39Q/+KiTv/ypkD/7J42/+WZM//jlzP/4pc1/+OYNv/jmTb/5Jk2/+SZNv/jmTb/45g2/+KXNf/jlzP/5Zkz/+yeNv/ypkD/4qJO/6d/UP9gTUD/Tj02/1pGOf9ZRTr/WEU5/1hFOf9YRTn/WEU5/1hFOf9XRDn6X0o+/3FbTGoAAAAAVVVVAwAAAAF/f38CAgICAGhURqNfSz7/WEU5+1lFOv1ZRjr/WUY6/1lGOv9ZRjr/WUY6/1tHO/9WRDn/Tj43/2RPQf+ZdU3/y5VQ/+ilS//zqEP/86Y9//GjOf/voDf/7p82/+6fNv/voDf/8aM5//OmPf/zqEP/6KVL/8uVUP+ZdU3/ZE9B/04+N/9WRDn/W0c7/1lGOv9ZRjr/WUY6/1lGOv9ZRjr/WUU6/VhFOftfSz7/aFRGowICAgB/f38CAAAAAQAAAAAAAAABAAAAAv/U1AZrVUiiYUxA/1pHO/9ZRjr7WkY6/FpGO/1aRjv+WkY7/lpGO/5aRzv+XEg7/ldEOf5PPjj+VUQ8/m1WRP6MbEv+qYBP/r6NUP7KlVD+0ZlQ/tGZUP7KlVD+vo1Q/qmAT/6MbEv+bVZE/lVEPP5PPjj+V0Q5/lxIO/5aRzv+WkY7/lpGO/5aRjv+WkY7/VpGOvxZRjr7Wkc7/2FMQP9rVUii/9TUBgAAAAIAAAABAAAAAAAAAAAAAAAA/wAAAQAAAAACAgIAdF9Ra2NOQuZhTUD/X0o+/1xIPP9bSDz/W0c8/1tHPP9bRzz/W0c8/1xIPP9eSTz/XEg7/1dEOf9SQDn/UEA5/1JCO/9WRT3/WEc+/1hHPv9WRT3/UkI7/1BAOf9SQDn/V0Q5/1xIO/9eSTz/XEg8/1tHPP9bRzz/W0c8/1tHPP9bSDz/XEg8/19KPv9hTUD/Y05C5nRfUWsCAgIAAAAAAP8AAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAABAAAAAKKLcxZyXU9taFNFt2NOQuBgTD/wYEtA8l9LQPNfS0DzX0tA819LQPNfS0DzYEtA82BMQPNiTUDzYk1A82FNQPNhTD7zYEs+82BLPvNhTD7zYU1A82JNQPNiTUDzYExA82BLQPNfS0DzX0tA819LQPNfS0DzX0tA82BLQPJgTD/wY05C4GhTRbdyXU9tootzFgAAAAAAAAABAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAVVVVAwAAAAAAAAAAAQEBALSWhxGRdGYjjHJkJoxyZCaMcmQmjHJkJoxyZCaMcmQmjHJkJoxyZCaMcmQmjHJkJoxyZCaMcmQmjHJkJoxyZCaMcmQmjHJkJoxyZCaMcmQmjHJkJoxyZCaMcmQmjHJkJoxyZCaMcmQmjHJkJoxyZCaRdGYjtJaHEQEBAQAAAAAAAAAAAFVVVQMAAAAAAAAAAAAAAAAAAAAAAAAAAA=="
$global:appIcon = $null
function Get-AppIcon {
    if ($null -ne $global:appIcon) { return $global:appIcon }
    try {
        $iconBytes = [System.Convert]::FromBase64String($global:embeddedAppIconIco)
        $iconStream = New-Object System.IO.MemoryStream(,$iconBytes)
        $global:appIcon = New-Object System.Drawing.Icon($iconStream)
    } catch { $global:appIcon = $null }
    return $global:appIcon
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "$($global:appTitle) $($global:appVersion)"
try { $appIconObj = Get-AppIcon; if ($null -ne $appIconObj) { $form.Icon = $appIconObj } } catch {}
# ClientSize, а не Size: нужно, чтобы 1080x700 было ИМЕННО внутренней рабочей
# областью окна, а не всем окном вместе с заголовком и рамкой — иначе высота
# заголовка (у FixedDialog она не резиновая, но всё равно отъедает несколько
# десятков пикселей) откусывала часть содержимого снизу (см. обрезанную
# нижнюю панель с прогресс-баром и кнопкой добавления).
$form.ClientSize = New-Object System.Drawing.Size(1080, 700)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.BackColor = $steamUi.Bg
$form.ForeColor = $steamUi.Text
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# Подсказка по клавишам — одна на обе панели (её же возвращаем после переноса игр).
$global:mainHintText = (T 'hint_main')
$labelHeader = New-Object System.Windows.Forms.Label
$labelHeader.Text = $global:mainHintText
# Статусная строка живёт прямо над общим прогресс-баром ($progressBarFolder),
# а не в шапке окна — сюда же выводятся текстовые статусы пакетного
# добавления/переноса папок (см. Invoke-SmartBatchAdd, Start-GameCopy и т.д.),
# поэтому она соседствует именно с прогрессом, который эти статусы поясняют.
$labelHeader.Location = New-Object System.Drawing.Point(20, 591)
$labelHeader.Size = New-Object System.Drawing.Size(1040, 24)
$labelHeader.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
$labelHeader.ForeColor = $steamUi.Text
$form.Controls.Add($labelHeader)

function New-MainPanelHeader($title, $path, $x, $width) {
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = $title
    $titleLabel.Location = New-Object System.Drawing.Point($x, 15)
    $titleLabel.Size = New-Object System.Drawing.Size(([int]$width - 50), 24)
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
    $titleLabel.ForeColor = $steamUi.Text
    $form.Controls.Add($titleLabel)
    return $titleLabel
}

$lblC = New-MainPanelHeader (T 'panel_extra') "" 20 470
$lblPathC = New-Object System.Windows.Forms.Label
$lblPathC.Location = New-Object System.Drawing.Point(20, 43)
$lblPathC.Size = New-Object System.Drawing.Size(358, 26)
$lblPathC.Font = New-Object System.Drawing.Font("Consolas", 8.2)
$lblPathC.BackColor = $steamUi.Input
$lblPathC.ForeColor = $steamUi.Text
$lblPathC.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$lblPathC.Padding = New-Object System.Windows.Forms.Padding(6, 0, 6, 0)
$lblPathC.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$lblPathC.AutoEllipsis = $true
$form.Controls.Add($lblPathC)

# Кнопка "Обзор..." выровнена по одной строке с полем пути (как в Steam).
$btnSelectC = New-Object System.Windows.Forms.Button
$btnSelectC.Text = (T 'browse')
$btnSelectC.Location = New-Object System.Drawing.Point(388, 43)
$btnSelectC.Size = New-Object System.Drawing.Size(90, 26)
$btnSelectC.FlatStyle = "Flat"
$btnSelectC.FlatAppearance.BorderColor = $steamUi.Border
$btnSelectC.FlatAppearance.MouseOverBackColor = $steamUi.Selected
$btnSelectC.BackColor = $steamUi.Panel
$btnSelectC.ForeColor = $steamUi.Text
$btnSelectC.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$btnSelectC.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnSelectC)

$txtSearchC = New-Object System.Windows.Forms.TextBox
$txtSearchC.Location = New-Object System.Drawing.Point(20, 76)
$txtSearchC.Size = New-Object System.Drawing.Size(458, 24)
$txtSearchC.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$txtSearchC.BackColor = $steamUi.Input
$txtSearchC.ForeColor = $steamUi.Text
$txtSearchC.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$form.Controls.Add($txtSearchC)
Set-TextBoxCue $txtSearchC (T 'search_cue')

$listBoxC = New-Object System.Windows.Forms.ListBox
$listBoxC.Location = New-Object System.Drawing.Point(20, 126)
$listBoxC.Size = New-Object System.Drawing.Size(458, 455)
$listBoxC.SelectionMode = "One"
$listBoxC.DrawMode = [System.Windows.Forms.DrawMode]::OwnerDrawFixed
$listBoxC.ItemHeight = 27
$listBoxC.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$listBoxC.BackColor = $steamUi.Input
$listBoxC.ForeColor = $steamUi.Text
$listBoxC.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$listBoxC.Tag = 'C'
Register-ListBoxDrawEvent $listBoxC
$form.Controls.Add($listBoxC)

# Заглушка-подсказка поверх левой панели: те же размеры и рамка, что у списка,
# но по центру — крупный текст. Показывается вместо списка, когда папку ещё
# нужно выбрать; панель при этом никуда не исчезает, просто пустая.
$lblEmptyC = New-Object System.Windows.Forms.Label
$lblEmptyC.Location = $listBoxC.Location
$lblEmptyC.Size = $listBoxC.Size
$lblEmptyC.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$lblEmptyC.BackColor = $steamUi.Input
$lblEmptyC.ForeColor = $steamUi.Muted
$lblEmptyC.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 13)
$lblEmptyC.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblEmptyC.Padding = New-Object System.Windows.Forms.Padding(24)
$lblEmptyC.Visible = $false
$form.Controls.Add($lblEmptyC)

$lblD = New-MainPanelHeader (T 'panel_main') "" 602 470
$lblPathD = New-Object System.Windows.Forms.Label
$lblPathD.Location = New-Object System.Drawing.Point(602, 43)
$lblPathD.Size = New-Object System.Drawing.Size(358, 26)
$lblPathD.Font = New-Object System.Drawing.Font("Consolas", 8.2)
$lblPathD.BackColor = $steamUi.Input
$lblPathD.ForeColor = $steamUi.Text
$lblPathD.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$lblPathD.Padding = New-Object System.Windows.Forms.Padding(6, 0, 6, 0)
$lblPathD.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$lblPathD.AutoEllipsis = $true
$form.Controls.Add($lblPathD)

# Кнопка "Обзор..." выровнена по одной строке с полем пути (как в Steam).
$btnSelectD = New-Object System.Windows.Forms.Button
$btnSelectD.Text = (T 'browse')
$btnSelectD.Location = New-Object System.Drawing.Point(970, 43)
$btnSelectD.Size = New-Object System.Drawing.Size(90, 26)
$btnSelectD.FlatStyle = "Flat"
$btnSelectD.FlatAppearance.BorderColor = $steamUi.Border
$btnSelectD.FlatAppearance.MouseOverBackColor = $steamUi.Selected
$btnSelectD.BackColor = $steamUi.Panel
$btnSelectD.ForeColor = $steamUi.Text
$btnSelectD.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$btnSelectD.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnSelectD)

$txtSearchD = New-Object System.Windows.Forms.TextBox
$txtSearchD.Location = New-Object System.Drawing.Point(602, 76)
$txtSearchD.Size = New-Object System.Drawing.Size(458, 24)
$txtSearchD.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$txtSearchD.BackColor = $steamUi.Input
$txtSearchD.ForeColor = $steamUi.Text
$txtSearchD.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$form.Controls.Add($txtSearchD)
Set-TextBoxCue $txtSearchD (T 'search_cue')

$listBoxD = New-Object System.Windows.Forms.ListBox
$listBoxD.Location = New-Object System.Drawing.Point(602, 126)
$listBoxD.Size = New-Object System.Drawing.Size(458, 455)
$listBoxD.SelectionMode = "One"
$listBoxD.DrawMode = [System.Windows.Forms.DrawMode]::OwnerDrawFixed
$listBoxD.ItemHeight = 27
$listBoxD.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$listBoxD.BackColor = $steamUi.Input
$listBoxD.ForeColor = $steamUi.Text
$listBoxD.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$listBoxD.Tag = 'D'
Register-ListBoxDrawEvent $listBoxD
$form.Controls.Add($listBoxD)

# Заглушка-подсказка поверх правой панели — тот же приём, что и слева.
$lblEmptyD = New-Object System.Windows.Forms.Label
$lblEmptyD.Location = $listBoxD.Location
$lblEmptyD.Size = $listBoxD.Size
$lblEmptyD.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$lblEmptyD.BackColor = $steamUi.Input
$lblEmptyD.ForeColor = $steamUi.Muted
$lblEmptyD.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 13)
$lblEmptyD.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblEmptyD.Padding = New-Object System.Windows.Forms.Padding(24)
$lblEmptyD.Text = (T 'empty_main')
$lblEmptyD.Visible = $false
$form.Controls.Add($lblEmptyD)

# --- Заголовок-сортировка "как в проводнике", общая механика для обеих панелей ---
# Вместо выпадающего списка — строка кликабельных "колонок" прямо над списком
# игр (Имя / Размер / Дата / В библиотеке), как заголовок ListView в Проводнике:
# клик по колонке сортирует по ней, повторный клик по уже активной колонке
# переключает направление, активная колонка подсвечивается и получает
# стрелку (▲ по возрастанию / ▼ по убыванию).
# AscCode/DescCode — те же коды режимов, что понимает switch в Apply-PanelView.
$script:sortColumns = @(
    [PSCustomObject]@{ Key='Name';    TextKey='col_name';   Width=238; MinWidth=100; TextPad=30; AscCode='NameAsc';    DescCode='NameDesc' },
    [PSCustomObject]@{ Key='Size';    TextKey='col_size';   Width=80;  MinWidth=55;  TextPad=8;  AscCode='SizeAsc';    DescCode='SizeDesc' },
    [PSCustomObject]@{ Key='Date';    TextKey='col_date';   Width=85;  MinWidth=65;  TextPad=8;  AscCode='DateAsc';    DescCode='DateDesc' },
    [PSCustomObject]@{ Key='Library'; TextKey='col_lib';   Width=36;  MinWidth=36;  TextPad=8;  AscCode='LibraryAsc'; DescCode='LibraryDesc' }
)
# Ширины колонок у каждой панели свои и меняются перетаскиванием границ в
# заголовке. Сумма ширин остаётся постоянной (458 px список − рамка − место под
# полосу прокрутки = 439), поэтому колонки всегда помещаются в список и не
# "уезжают" под скролл: граница двигается за счёт соседней колонки справа.
$script:colWidths = @{
    C = [int[]]@($script:sortColumns | ForEach-Object { $_.Width })
    D = [int[]]@($script:sortColumns | ForEach-Object { $_.Width })
}
$script:colMinWidths = [int[]]@($script:sortColumns | ForEach-Object { $_.MinWidth })
$script:colDrag = $null
# Все элементы заголовка каждой панели: Labels (колонки), Grips (границы), Cb (галочка "выбрать всё").
$script:headerParts = @{ C = $null; D = $null }

# Расставляет подписи колонок и ползунки-границы по текущим ширинам панели.
function Set-HeaderLayout ([string]$source) {
    $parts = $script:headerParts[$source]
    if ($parts -eq $null) { return }
    $w = $script:colWidths[$source]
    $cx = 0
    for ($i = 0; $i -lt $script:sortColumns.Count; $i++) {
        $col = $script:sortColumns[$i]
        $parts.Labels[$col.Key].SetBounds($cx, 0, [int]$w[$i], 22)
        $cx += [int]$w[$i]
        if ($i -lt $parts.Grips.Count) { $parts.Grips[$i].Left = $cx - 3 }
    }
}

# Создаёт строку заголовков-сортировщиков для одной панели ('C' или 'D') и
# возвращает хэш Key -> Label, чтобы потом обновлять текст/цвет активной
# колонки в Update-SortHeaderUI.
function New-SortHeaderRow ($x, $y, $source) {
    $listRef = if ($source -eq 'C') { $listBoxC } else { $listBoxD }
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point($x, $y)
    $panel.Size = New-Object System.Drawing.Size($listRef.Width, 22)
    $panel.BackColor = $steamUi.Panel
    $panel.Tag = $source
    $form.Controls.Add($panel)

    $labels = @{}
    foreach ($col in $script:sortColumns) {
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Location = New-Object System.Drawing.Point(0, 0)
        $lbl.Size = New-Object System.Drawing.Size([int]$col.Width, 22)
        $lbl.Text = (T $col.TextKey)
        $lbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $lbl.AutoEllipsis = $true
        $lbl.Padding = New-Object System.Windows.Forms.Padding([int]$col.TextPad, 0, 0, 0)
        $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 8.3)
        $lbl.ForeColor = if ($col.Key -eq 'Library') { $steamUi.Green } else { $steamUi.Muted }
        $lbl.BackColor = $steamUi.Panel
        $lbl.Cursor = [System.Windows.Forms.Cursors]::Hand
        # ВАЖНО: источник панели ('C'/'D') кладём в Tag ВМЕСТЕ с колонкой, а не
        # берём из параметра $source через .GetNewClosure() — closure заводит
        # обработчику свой изолированный scope, и запись в $script:panelSortC/D
        # внутри него уходит мимо того scope, который читает Apply-PanelView
        # (кнопки визуально не реагируют). $this.Tag работает без closure и
        # без побочных эффектов — тот же приём уже используется в файле для
        # миниатюр обложек (см. $pb.Tag=$url выше по файлу).
        $lbl.Tag = [PSCustomObject]@{ Source = $source; Column = $col }
        $panel.Controls.Add($lbl)
        $labels[$col.Key] = $lbl

        $lbl.Add_Click({
            $info = $this.Tag
            $col = $info.Column
            $src = $info.Source
            $curMode = if ($src -eq 'C') { $script:panelSortC } else { $script:panelSortD }
            $newMode = if ($curMode -eq $col.AscCode) { $col.DescCode } else { $col.AscCode }
            if ($src -eq 'C') { $script:panelSortC = $newMode } else { $script:panelSortD = $newMode }
            Apply-PanelView $src
        })
        $lbl.Add_MouseEnter({ if ($this.ForeColor -ne $steamUi.Accent) { $this.ForeColor = $steamUi.Text } })
        $lbl.Add_MouseLeave({
            $info = $this.Tag
            $col = $info.Column
            $src = $info.Source
            $curMode = if ($src -eq 'C') { $script:panelSortC } else { $script:panelSortD }
            if ($curMode -ne $col.AscCode -and $curMode -ne $col.DescCode) { $this.ForeColor = if ($col.Key -eq 'Library') { $steamUi.Green } else { $steamUi.Muted } }
        })
    }

    # Ползунки на границах колонок (между Имя|Размер, Размер|Дата, Дата|В библиотеке).
    # Тянешь границу мышкой — левая колонка меняется, правая компенсирует, так что
    # общая ширина не меняется. Позицию мыши берём в экранных координатах
    # ([Cursor]::Position): координаты внутри самого ползунка "прыгают", пока он
    # едет за курсором.
    $grips = @()
    for ($i = 0; $i -lt ($script:sortColumns.Count - 1); $i++) {
        $grip = New-Object System.Windows.Forms.Panel
        $grip.Size = New-Object System.Drawing.Size(7, 22)
        $grip.Location = New-Object System.Drawing.Point(0, 0)
        $grip.BackColor = $steamUi.Panel
        $grip.Cursor = [System.Windows.Forms.Cursors]::SizeWE
        $grip.Tag = [PSCustomObject]@{ Source = $source; Index = $i }
        $grip.Add_Paint({
            param($s, $pe)
            $linePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(84,100,118))
            $pe.Graphics.DrawLine($linePen, 3, 4, 3, 17)
            $linePen.Dispose()
        })
        $grip.Add_MouseEnter({ $this.BackColor = $steamUi.Selected })
        $grip.Add_MouseLeave({ if ($script:colDrag -eq $null) { $this.BackColor = $steamUi.Panel } })
        $grip.Add_MouseDown({
            param($s, $me)
            if ($me.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
            $info = $s.Tag
            $cw = $script:colWidths[$info.Source]
            $script:colDrag = [PSCustomObject]@{
                Source = $info.Source
                Index  = $info.Index
                StartX = [System.Windows.Forms.Cursor]::Position.X
                W0     = [int]$cw[$info.Index]
                W1     = [int]$cw[$info.Index + 1]
            }
        })
        $grip.Add_MouseMove({
            $d = $script:colDrag
            if ($d -eq $null) { return }
            $delta = [System.Windows.Forms.Cursor]::Position.X - $d.StartX
            $min0 = [int]$script:colMinWidths[$d.Index]
            $min1 = [int]$script:colMinWidths[$d.Index + 1]
            $sum = $d.W0 + $d.W1
            $newW0 = [Math]::Max($min0, [Math]::Min($sum - $min1, $d.W0 + $delta))
            $cw = $script:colWidths[$d.Source]
            $cw[$d.Index] = [int]$newW0
            $cw[$d.Index + 1] = [int]($sum - $newW0)
            Set-HeaderLayout $d.Source
            $lb = if ($d.Source -eq 'C') { $listBoxC } else { $listBoxD }
            $lb.Invalidate()
        })
        $grip.Add_MouseUp({
            $script:colDrag = $null
            $this.BackColor = $steamUi.Panel
        })
        $panel.Controls.Add($grip)
        $grips += $grip
    }

    # Галочка "выбрать всё" — прямо над галочками строк (тот же отступ 8 px слева).
    # Состояния: пусто / все отмечены / отмечена часть (чёрточка). Само состояние
    # пересчитывает Update-SelectAllCheckbox из Update-MainLibraryButtonState.
    $cb = New-Object System.Windows.Forms.Panel
    $cb.Location = New-Object System.Drawing.Point(2, 0)
    $cb.Size = New-Object System.Drawing.Size(24, 22)
    $cb.BackColor = $steamUi.Panel
    $cb.Cursor = [System.Windows.Forms.Cursors]::Hand
    $cb.Tag = 0
    $cb.Add_Paint({
        param($s, $pe)
        $state = [int]$s.Tag
        $r = New-Object System.Drawing.Rectangle(6, 4, 14, 14)
        if ($state -ge 1) {
            $fillBrush = New-Object System.Drawing.SolidBrush($steamUi.Accent)
            $pe.Graphics.FillRectangle($fillBrush, $r)
            $fillBrush.Dispose()
            $markPen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 1.6)
            if ($state -eq 1) {
                $pe.Graphics.DrawLine($markPen, $r.X + 3, $r.Y + 7, $r.X + 6, $r.Y + 10)
                $pe.Graphics.DrawLine($markPen, $r.X + 6, $r.Y + 10, $r.X + 11, $r.Y + 3)
            } else {
                $pe.Graphics.DrawLine($markPen, $r.X + 3, $r.Y + 7, $r.X + 11, $r.Y + 7)
            }
            $markPen.Dispose()
        } else {
            $borderPen = New-Object System.Drawing.Pen($steamUi.Muted, 1.2)
            $pe.Graphics.DrawRectangle($borderPen, $r)
            $borderPen.Dispose()
        }
    })
    $cb.Add_MouseClick({
        param($s, $me)
        if ($me.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Set-AllRowsChecked ([string]$s.Parent.Tag) }
    })
    $panel.Controls.Add($cb)
    $cb.BringToFront()

    $script:headerParts[$source] = @{ Labels = $labels; Grips = $grips; Cb = $cb }
    foreach ($g in $grips) { $g.BringToFront() }
    Set-HeaderLayout $source
    return $labels
}

# Подсвечивает активную колонку (жирным + акцентным цветом + стрелкой ▲/▼),
# остальные возвращает в обычный вид. Вызывается из Apply-PanelView, то есть
# всегда синхронна с тем, что реально отсортировано на экране.
function Update-SortHeaderUI ([string]$source) {
    $labels = if ($source -eq 'C') { $script:sortHeaderLabelsC } else { $script:sortHeaderLabelsD }
    if ($labels -eq $null) { return }
    $mode = if ($source -eq 'C') { $script:panelSortC } else { $script:panelSortD }
    foreach ($col in $script:sortColumns) {
        $lbl = $labels[$col.Key]
        if ($mode -eq $col.AscCode) {
            $lbl.Text = (T $col.TextKey) + " ▲"
            $lbl.ForeColor = $steamUi.Accent
            $lbl.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8.3)
        } elseif ($mode -eq $col.DescCode) {
            $lbl.Text = (T $col.TextKey) + " ▼"
            $lbl.ForeColor = $steamUi.Accent
            $lbl.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8.3)
        } else {
            $lbl.Text = (T $col.TextKey)
            $lbl.ForeColor = if ($col.Key -eq 'Library') { $steamUi.Green } else { $steamUi.Muted }
            $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 8.3)
        }
    }
}

# Состояние галочки "выбрать всё" над списком: 0 — ничего не отмечено (или список
# пуст), 1 — отмечены все строки списка, 2 — отмечена только часть.
function Update-SelectAllCheckbox ([string]$source) {
    $parts = $script:headerParts[$source]
    if ($parts -eq $null) { return }
    $listBox = if ($source -eq 'C') { $listBoxC } else { $listBoxD }
    $checkedSet = Get-CheckedSet $source
    $total = $listBox.Items.Count
    $marked = 0
    for ($i = 0; $i -lt $total; $i++) {
        if ($checkedSet.ContainsKey((Clean-GameName $listBox.Items[$i].ToString()))) { $marked++ }
    }
    $state = if ($total -eq 0 -or $marked -eq 0) { 0 } elseif ($marked -eq $total) { 1 } else { 2 }
    if ([int]$parts.Cb.Tag -ne $state) {
        $parts.Cb.Tag = $state
        $parts.Cb.Invalidate()
    }
}

# Клик по галочке "выбрать всё": если в списке отмечены не все игры — отмечает все
# (с учётом текущего поиска — только те, что сейчас видны), если уже отмечены все —
# снимает отметки с них.
function Set-AllRowsChecked ([string]$source) {
    $listBox = if ($source -eq 'C') { $listBoxC } else { $listBoxD }
    $checkedSet = Get-CheckedSet $source
    $names = @()
    for ($i = 0; $i -lt $listBox.Items.Count; $i++) { $names += (Clean-GameName $listBox.Items[$i].ToString()) }
    if ($names.Count -eq 0) { return }
    $allChecked = $true
    foreach ($n in $names) { if (-not $checkedSet.ContainsKey($n)) { $allChecked = $false; break } }
    foreach ($n in $names) {
        if ($allChecked) { $checkedSet.Remove($n) | Out-Null } else { $checkedSet[$n] = $true }
    }
    $listBox.Invalidate()
    Update-MainLibraryButtonState
}

$script:sortHeaderLabelsC = New-SortHeaderRow 20 104 'C'
$script:sortHeaderLabelsD = New-SortHeaderRow 602 104 'D'

# Поиск — с той же задержкой в 350 мс, что и автопоиск обложек по названию
# (см. $titleSearchTimer дальше в файле), чтобы не пересобирать список на
# каждое нажатие клавиши, а только когда пользователь на миг остановился.
$searchTimerC = New-Object System.Windows.Forms.Timer
$searchTimerC.Interval = 350
$searchTimerC.Add_Tick({
    $searchTimerC.Stop()
    $script:panelSearchC = $txtSearchC.Text
    Apply-PanelView 'C'
})
$txtSearchC.Add_TextChanged({ $searchTimerC.Stop(); $searchTimerC.Start() })

$searchTimerD = New-Object System.Windows.Forms.Timer
$searchTimerD.Interval = 350
$searchTimerD.Add_Tick({
    $searchTimerD.Stop()
    $script:panelSearchD = $txtSearchD.Text
    Apply-PanelView 'D'
})
$txtSearchD.Add_TextChanged({ $searchTimerD.Stop(); $searchTimerD.Start() })

$global:lastFocusedPanel = 'C'

$btnMoveGame = New-Object System.Windows.Forms.Button
$btnMoveGame.Text = (T 'btn_move')
$btnMoveGame.Location = New-Object System.Drawing.Point(492, 280)
$btnMoveGame.Size = New-Object System.Drawing.Size(100, 48)
$btnMoveGame.FlatStyle = "Flat"
$btnMoveGame.FlatAppearance.BorderColor = $steamUi.Border
$btnMoveGame.FlatAppearance.MouseOverBackColor = $steamUi.Selected
$btnMoveGame.BackColor = $steamUi.Panel
$btnMoveGame.ForeColor = $steamUi.Accent
$btnMoveGame.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8.7)
$btnMoveGame.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnMoveGame)

$btnRefreshLibrary = New-Object System.Windows.Forms.Button
$btnRefreshLibrary.Text = (T 'btn_refresh')
$btnRefreshLibrary.Location = New-Object System.Drawing.Point(492, 338)
$btnRefreshLibrary.Size = New-Object System.Drawing.Size(100, 48)
$btnRefreshLibrary.FlatStyle = "Flat"
$btnRefreshLibrary.FlatAppearance.BorderColor = $steamUi.Border
$btnRefreshLibrary.FlatAppearance.MouseOverBackColor = $steamUi.Selected
$btnRefreshLibrary.BackColor = $steamUi.Panel
$btnRefreshLibrary.ForeColor = $steamUi.Text
$btnRefreshLibrary.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
$btnRefreshLibrary.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnRefreshLibrary)


$progressBarFolder = New-Object System.Windows.Forms.ProgressBar
$progressBarFolder.Location = New-Object System.Drawing.Point(20, 621)
$progressBarFolder.Size = New-Object System.Drawing.Size(1000, 14)
$progressBarFolder.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
$form.Controls.Add($progressBarFolder)

# Процент справа от самого бара, а не поверх него: Label с прозрачным фоном
# поверх нативно отрисовываемого ProgressBar в WinForms подёргивается при
# перерисовке, а нам ещё важно, чтобы это было видно даже когда бар почти
# пустой (пары пикселей закраски не разглядеть). Раньше о прогрессе было
# известно только по тексту статусной строки ($labelHeader) — сейчас это
# ещё и процент рядом с самим баром.
$lblProgressPercent = New-Object System.Windows.Forms.Label
$lblProgressPercent.Location = New-Object System.Drawing.Point(1024, 618)
$lblProgressPercent.Size = New-Object System.Drawing.Size(36, 20)
$lblProgressPercent.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$lblProgressPercent.ForeColor = $steamUi.Muted
$lblProgressPercent.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$lblProgressPercent.Text = ""
$form.Controls.Add($lblProgressPercent)

# Бар выставляется из десятка разных мест по файлу напрямую через
# ".Value = ...", поэтому вместо правки каждого места процент читается
# таймером — исправно тикает и во время синхронных операций, потому что все
# они и так гоняют [Application]::DoEvents() в цикле (тот же приём, которым
# в этом файле уже держат отзывчивым UI во время долгих операций).
$progressPercentTimer = New-Object System.Windows.Forms.Timer
$progressPercentTimer.Interval = 120
$progressPercentTimer.Add_Tick({
    try {
        $v = $progressBarFolder.Value
        $lblProgressPercent.Text = if ($v -gt 0 -and $v -lt 100) { "$v%" } else { "" }
    } catch {}
})
$progressPercentTimer.Start()

# Нижняя панель пакетного добавления: слева HD-переключатель режима автозаполнения,
# справа — большая кнопка запуска пакетного добавления.
# Выключено: игры добавляются по одной — карточка каждой открывается отдельным
# диалогом с тремя кнопками внизу (Show-GameEditorDialog в цикле, см. конец файла).
# Включено: игры, для которых уверенно определились и название, и exe,
# добавляются автоматически без показа карточки (Add-GameToSteamQuietly), а
# карточки остальных игр открываются той же карточкой, одна за другой, тоже
# отдельными диалогами (см. Invoke-SmartBatchAdd в конце файла). Общий
# прогресс на весь пакет — $progressBarFolder главного окна (он же показывает
# перенос папок между панелями), статус — $labelHeader.
$script:batchAutoFillEnabled = $false

$pnlBatchActions = New-Object System.Windows.Forms.Panel
$pnlBatchActions.Location = New-Object System.Drawing.Point(20, 643)
$pnlBatchActions.Size = New-Object System.Drawing.Size(1040, 42)
$pnlBatchActions.BackColor = $form.BackColor
$form.Controls.Add($pnlBatchActions)

$lblBatchAuto = New-Object System.Windows.Forms.Label
$lblBatchAuto.Text = (T 'batch_auto')
$lblBatchAuto.Location = New-Object System.Drawing.Point(58, 11)
$lblBatchAuto.Size = New-Object System.Drawing.Size(167, 20)
$lblBatchAuto.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblBatchAuto.ForeColor = $steamUi.Text
$lblBatchAuto.Cursor = [System.Windows.Forms.Cursors]::Hand
$pnlBatchActions.Controls.Add($lblBatchAuto)

# HD-переключатель в стиле Steam: отрисовывается одним double-buffered контролом
# с аппаратно-независимым сглаживанием, без Region/Panel-ступенек.
$pnlBatchToggle = New-Object SteamToggleSwitch
$pnlBatchToggle.Location = New-Object System.Drawing.Point(8, 9)
$pnlBatchToggle.Size = New-Object System.Drawing.Size(42, 24)
$pnlBatchActions.Controls.Add($pnlBatchToggle)

# Подсказка: на переключателе не всегда очевидно, что он включает именно
# ПАКЕТНОЕ автозаполнение сразу нескольких карточек, а не что-то другое.
# Вешаем на оба элемента (сам тумблер и его подпись), чтобы наведение
# работало на всей кликабельной зоне, а не только на маленьком квадратике.
$mainToolTip = New-Object System.Windows.Forms.ToolTip
$mainToolTip.AutoPopDelay = 8000
$mainToolTip.InitialDelay = 400
$mainToolTip.ReshowDelay = 200
$batchAutoTooltipText = (T 'batch_auto_tip')
$mainToolTip.SetToolTip($pnlBatchToggle, $batchAutoTooltipText)
$mainToolTip.SetToolTip($lblBatchAuto, $batchAutoTooltipText)
foreach ($hs in @('C','D')) {
    try { $mainToolTip.SetToolTip($script:headerParts[$hs].Cb, (T 'tip_select_all')) } catch {}
    try { $mainToolTip.SetToolTip($script:headerParts[$hs].Labels['Library'], (T 'tip_lib_header')) } catch {}
}

# Подсказки на галочках внутри строк: строки рисуются вручную (это не отдельные
# контролы), поэтому подсказку меняем по положению мыши над списком — текст
# перезадаём только когда он реально поменялся, чтобы она не мигала.
$script:rowTipText = @{ C = ''; D = '' }
foreach ($tipList in @($listBoxC, $listBoxD)) {
    $tipList.Add_MouseMove({
        $lb = $this
        $src = [string]$lb.Tag
        $tipText = ''
        $idx = $lb.IndexFromPoint($_.Location)
        if ($idx -ge 0 -and $idx -lt $lb.Items.Count) {
            $w = $script:colWidths[$src]
            $libStart = [int]$w[0] + [int]$w[1] + [int]$w[2]
            if ($_.X -lt 28) {
                $tipText = (T 'tip_row_check')
            } elseif ($_.X -ge $libStart -and $_.X -lt ($libStart + [int]$w[3])) {
                $rowName = Clean-GameName $lb.Items[$idx].ToString()
                if ($global:installedSteamGames.ContainsKey((Get-NormalizedGameKey $rowName))) { $tipText = (T 'tip_row_installed') }
            }
        }
        if ($script:rowTipText[$src] -ne $tipText) {
            $script:rowTipText[$src] = $tipText
            try { $mainToolTip.Hide($lb) } catch {}
            $mainToolTip.SetToolTip($lb, $tipText)
        }
    })
}

$updateBatchToggle = {
    $pnlBatchToggle.Checked = [bool]$script:batchAutoFillEnabled
}

$toggleBatchAutoFill = {
    $script:batchAutoFillEnabled = -not $script:batchAutoFillEnabled
    & $updateBatchToggle
}
$pnlBatchToggle.Add_Click($toggleBatchAutoFill)
$pnlBatchToggle.Add_CheckedChanged({
    $script:batchAutoFillEnabled = [bool]$pnlBatchToggle.Checked
})
$lblBatchAuto.Add_Click($toggleBatchAutoFill)

# Центральная кнопка добавления — компактная и строго центрирована
# относительно окна, а не растянута до шестерёнки.
$btnAddToSteam = New-Object System.Windows.Forms.Button
$btnAddToSteam.Text = (T 'btn_add_batch')
$btnAddToSteam.Location = New-Object System.Drawing.Point(260, 0)
$btnAddToSteam.Size = New-Object System.Drawing.Size(520, 42)
$btnAddToSteam.FlatStyle = "Flat"
$btnAddToSteam.FlatAppearance.BorderColor = $steamUi.Accent2
$btnAddToSteam.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(35,78,106)
$btnAddToSteam.BackColor = [System.Drawing.Color]::FromArgb(25,55,75)
$btnAddToSteam.ForeColor = $steamUi.Text
$btnAddToSteam.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10.5)
# Появляется только когда отмечено 2+ игры галочками (см. Update-MainLibraryButtonState) —
# для одной игры добавление идёт через клик по ней -> кнопку внутри её карточки.
$btnAddToSteam.Visible = $false
$pnlBatchActions.Controls.Add($btnAddToSteam)

# Кнопка настроек в стиле Steam.
# Используется отдельный PNG самого Steam-стиля, чтобы форма шестерёнки
# совпадала с визуальным эталоном, а не зависела от Unicode-шрифта Windows.
$btnSettings = New-Object System.Windows.Forms.Button
$btnSettings.Text = ''
$btnSettings.Location = New-Object System.Drawing.Point(992, 0)
$btnSettings.Size = New-Object System.Drawing.Size(48, 42)
$btnSettings.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnSettings.FlatAppearance.BorderSize = 0
$btnSettings.FlatAppearance.MouseOverBackColor = $steamUi.Panel
$btnSettings.FlatAppearance.MouseDownBackColor = $steamUi.Panel
$btnSettings.BackColor = [System.Drawing.Color]::Transparent
$btnSettings.ForeColor = $steamUi.Text
# Steam-style gear icon is embedded so the button does not disappear when
# the script is launched from a location where the optional assets folder is absent.
$settingsGearBase64 = 'iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAYAAACM/rhtAAAFJUlEQVR42u1YW2gUVxj+zjkzm91NNtVMkt1NdlA3hkZNWps0XvDBkLU+GKMSsIXSwtrSivRZoTeKoE0f2jy2UCiRQiOYwnZJ1URJbDRKddlWScZasGxCEqYb3YLufXb2TB9ktrHog2a3CM33NHDmP+ef7/tvZ4BlLA3E4/E89yw7KIiiaH+mHZQkqZkQsnQpCGHms2EYBgD+/4jBYm3k8XgqRVEsJ4TQdDp9V1XVbFEkLsYmjY2NDV1dXScrKipkm81WPTEx8b6qqp8XY2+6FGOn00kBwOFwyFu2bGmXZdnV0NAgyLLcUSxlntjB9vb2Vw4cOHDK6/V6otEoBwCv19tlGAY450gmk/B6vV0tLS0vmzY9PT29e/bs+eRpHGRP8nJra+t2v98/unHjxg2SJPXY7Xa+c+fOTzdt2vQGIQSMMRiGAYfDgZqamq7Kykpx27Zt7+3du/dQU1NTh81mq5ucnPyxJElSX19ffuTIkYQkSchkMrBarSCEQBRFpFIpPKgshTIDm80GzjlEUUQikQClFJxzDA0N9QYCgQ+KLrFhGDwSiYRMp3K5HDRNQzwef8gxwzBAKUU6nYamaUgkEmCMgTEGXdcRiUROl0TieDyu379//+f6+vo3q6qqLIQQmLJyzsEYg91uhyAI0HW9sMYYA6UPeAgEAh9fvHjxu5Ilyc2bNyetVmuFeSAhpCDnvXv3cOHChfPXrl27zhiD1WoF5/80E8455ubmxktaB7du3brP6XTCZM+Mq7GxsdPnzp17W9O0OKWUjY6Obti/f/9Pa9euLcvlcg8OEgTs2rXr5MLCQtP8/HyiaEnS2tq6fffu3d9LklRts9lgt9th9m5KKUKh0PW+vr6X/m3X3NzcevDgwbDT6YSmaYWPikajiMViqqIo/YFA4MMlS1xTU/NiY2NjtSzLcDgcBVkFQUAikcDly5c/epTd1NTUL6lUCow9HOZ1dXXYvHmzu7m5+a2ixCAhhOm6jmw2C855QVoAYIyhvLzc/TjbWCz2O+cclNIC67lcDoZhgBAiFDVJTIkWlxRRFCFJ0rrH2UiS9LzJoPlhlFKzZhpFKTOZTOY3RVGGFUWZYIytc7vdknmIIAhgjL0wPz8/GIvF/lps5/f7B9ra2lrMTKaUIpvNIhgM9k1MTAxcvXr12J07d6JFHbfcbrfl6NGj2ZUrVyKfzxeYiUQiCAaD+2ZnZ8dEUSzfsWPH152dnd1mlpvsDw8Pn+rv73+tZGVGVVVtdnb2zxUrVrgWS71mzRocPnz4B5NZXdeRz+fNWAMhBPl8HlNTU9+UdJrp6Ojwr1+/3mXGotnaOOfIZrNIpVJIp9PQdb2wVmBCEODz+b50u92Wkk0zvb29v5aVlUHTNFBKYbVaCxPM4iQghEAQhMK62fpkWa7KZDLuycnJoaIz6HK5xHA4PGWxWGCxWMAYw/T0NKLR6KMGC8Tjcdy+fRuqqsK0icVimJ6eHikJg4lEgl+5cuUrj8fzusvlks6ePTsYDAZfVRQl6HA4fLIsO3K5HBhjSCaTOHPmzBeBQGDfrVu3Tq9evdpPCMHAwMCh8fHxb0t+0+ru7n6oe/h8vndGRkaMEydOGIODg8bx48ezq1atqjbX29raOn0+37v/2aVpaGjoWG1tLQGAhYUFQ9O0uCAIqK2tRVVVFS5duhSemZm5a74fDofHAIyVfORfjGQyiWQyaRbhhbm5ubyiKMqNGzf+CIVCn6mqOrP8Z+lpYEq/jGUsYxnLKA7+BhpFJoT/p7x0AAAAAElFTkSuQmCC'
$settingsIcon = $null
try {
    $gearBytes = [System.Convert]::FromBase64String($settingsGearBase64)
    $gearStream = New-Object System.IO.MemoryStream(,$gearBytes)
    $settingsIcon = [System.Drawing.Image]::FromStream($gearStream)
    $btnSettings.BackgroundImage = $settingsIcon
    $btnSettings.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::Center
} catch {
    $settingsIcon = $null
}
$btnSettings.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnSettings.TabStop = $false
$btnSettings.AccessibleName = (T 'settings_title')
$btnSettings.AccessibleDescription = (T 'settings_desc')
$pnlBatchActions.Controls.Add($btnSettings)

$pnlBatchActions.Add_Resize({
    try {
        $btnAddToSteam.Left = [int](($pnlBatchActions.ClientSize.Width - $btnAddToSteam.Width) / 2)
        $btnSettings.Left = $pnlBatchActions.ClientSize.Width - $btnSettings.Width
    } catch {}
})

function Save-Configuration {
    try {
        $configData = @(
            "dirC=$($global:dirC)",
            "dirD=$($global:dirD)",
            "steamInstallPath=$($global:steamInstallPath)",
            "steamUserId=$($global:steamUserId)",
            "steamGridDbApiKey=$($global:steamGridDbApiKey)",
            "backupFolderPath=$($global:backupFolderPath)",
            "language=$($global:language)"
        )
        $configData | Out-File $global:configPath -Encoding UTF8 -Force -ErrorAction SilentlyContinue
    } catch {}
}

$form.Add_FormClosing({ Save-Configuration; Remove-TemporaryCovers })

# Игры, убранные из списка клавишей Delete. Это ТОЛЬКО скрытие в интерфейсе:
# папки на диске не трогаются. Действует до кнопки «Обновить» или перезапуска.
# Ключ включает путь корневой папки, поэтому при смене папки записи не путаются.
$global:hiddenGames = @{}

# Игры, отмеченные галочкой в панели (для «Перенести»/«Добавить несколько»).
# Карточка игры открывается двойным кликом по строке или клавишей Enter —
# одиночный клик только выделяет строку. Галочки — отдельный, независимый
# механизм именно для пакетных операций (перенос между панелями, добавление
# сразу нескольких игр).
# Ключ — очищенное имя игры (Clean-GameName), отдельно для каждой панели.
$global:checkedC = @{}
$global:checkedD = @{}
function Get-CheckedSet ([string]$source) {
    if ($source -eq 'C') { return $global:checkedC } else { return $global:checkedD }
}
function Get-CheckedGames {
    $result = @()
    foreach ($name in @($global:checkedC.Keys)) { $result += [PSCustomObject]@{Name=$name; Source='C'; Path=(Join-Path $global:dirC $name)} }
    foreach ($name in @($global:checkedD.Keys)) { $result += [PSCustomObject]@{Name=$name; Source='D'; Path=(Join-Path $global:dirD $name)} }
    # $global:checkedC/D — обычные Hashtable: порядок .Keys в них не определён, поэтому
    # без сортировки карточки в пакетном добавлении шли в случайном порядке.
    # Сортируем так же, как панели по умолчанию (Sort-Object -Property Name).
    return @($result | Sort-Object -Property Name)
}
# Прямоугольник галочки внутри строки списка: квадрат 14x14, вертикально
# отцентрирован, с отступом 8px от левого края строки.
function Get-RowCheckboxRect ($itemBounds) {
    $size = 14
    $x = $itemBounds.X + 8
    $y = $itemBounds.Y + [int](($itemBounds.Height - $size) / 2)
    return New-Object System.Drawing.Rectangle($x, $y, $size, $size)
}

# Кликабельная зона галочки — ЗНАЧИТЕЛЬНО больше самого квадратика 14x14.
# Раньше хит-тест использовал тот же тесный прямоугольник, что и отрисовка:
# промах на пару пикселей выше/ниже центра строки уходил в клик "по игре" и
# открывал карточку. Теперь зона занимает всю высоту строки (сверху донизу,
# без зазоров между соседними строками) и расширена по ширине — от левого
# края строки до отступа с запасом вокруг видимого квадратика.
function Get-RowCheckboxHitRect ($itemBounds) {
    $x = $itemBounds.X
    $y = $itemBounds.Y
    $width = 28
    $height = $itemBounds.Height
    return New-Object System.Drawing.Rectangle($x, $y, $width, $height)
}

function Get-HiddenGameKey ([string]$source, [string]$folderName) {
    $root = if ($source -eq 'C') { [string]$global:dirC } else { [string]$global:dirD }
    return ($root + '|' + $folderName).ToLowerInvariant()
}

# ===================== ПОИСК / СОРТИРОВКА ПО ПАНЕЛЯМ =====================
# Полные (нефильтрованные) списки игр каждой панели — заполняются в
# Refresh-Panels из диска, а строка поиска и сортировка дальше работают уже
# только с этим массивом в памяти, без повторного обращения к диску.
$script:panelDataC = @()
$script:panelDataD = @()
# Имя папки -> дата изменения; заполняется в Apply-PanelView, читается при отрисовке колонки "Дата".
$script:panelDateMapC = @{}
$script:panelDateMapD = @{}
$script:panelSearchC = ''
$script:panelSearchD = ''
$script:panelSortC = 'NameAsc'
$script:panelSortD = 'NameAsc'

# Кэш посчитанных размеров папок (полный путь -> байты), на всю сессию.
# Заполняется и клавишей Space (Show-SelectedGameSize), и сортировкой "по
# размеру" (Ensure-FolderSizesCached) — они делят один и тот же кэш, поэтому
# повторный подсчёт одной и той же папки не происходит.
$global:folderSizeCache = @{}

function Get-FolderSizeCached ([string]$path) {
    $key = $path.ToLowerInvariant()
    if ($global:folderSizeCache.ContainsKey($key)) { return [int64]$global:folderSizeCache[$key] }
    return -1
}

# Досчитывает размер только тех папок из переданного набора, которых ещё нет
# в кэше — со статусом и прогресс-баром главного окна (тот же DoEvents-приём,
# что и везде в этом файле), чтобы сортировка "по размеру" не выглядела так,
# будто программа зависла на большой библиотеке.
function Ensure-FolderSizesCached ($items) {
    $missing = @($items | Where-Object { $global:folderSizeCache.ContainsKey($_.Path.ToLowerInvariant()) -eq $false })
    if ($missing.Count -eq 0) { return }
    $prevText = $labelHeader.Text
    $prevValue = $progressBarFolder.Value
    $i = 0
    try {
        foreach ($item in $missing) {
            $i++
            $labelHeader.Text = (T 'st_sizes_sort' @($item.Name, $i, $missing.Count))
            $progressBarFolder.Value = [Math]::Min(100, [int](($i / $missing.Count) * 100))
            [System.Windows.Forms.Application]::DoEvents()
            try { $global:folderSizeCache[$item.Path.ToLowerInvariant()] = Get-FolderSize $item.Path } catch {}
        }
    } finally {
        $progressBarFolder.Value = $prevValue
        $labelHeader.Text = $prevText
    }
}

# Применяет текущие поиск+сортировку панели ($script:panelSearchX /
# $script:panelSortX) к уже загруженному в память $script:panelDataX и
# перерисовывает соответствующий ListBox. Диск заново НЕ читается — это
# отдельная, дешёвая операция от Refresh-Panels, вызывается при каждом
# нажатии в строке поиска и при смене сортировки.
function Apply-PanelView ([string]$source, [string[]]$forceSelectedNames = $null) {
    $listBox   = if ($source -eq 'C') { $listBoxC } else { $listBoxD }
    $data      = if ($source -eq 'C') { $script:panelDataC } else { $script:panelDataD }
    $search    = if ($source -eq 'C') { $script:panelSearchC } else { $script:panelSearchD }
    $sortMode  = if ($source -eq 'C') { $script:panelSortC } else { $script:panelSortD }

    # По умолчанию сохраняем то, что уже выделено в списке (сценарий смены
    # поиска/сортировки на живом списке). Refresh-Panels, где список в момент
    # вызова уже очищен, передаёт имена явно через $forceSelectedNames.
    $selectedNames = if ($null -ne $forceSelectedNames) { @($forceSelectedNames) } else { @($listBox.SelectedItems | ForEach-Object { [string]$_ }) }

    $view = @($data)
    if (-not [string]::IsNullOrWhiteSpace($search)) {
        $needle = $search.Trim()
        $view = @($view | Where-Object { $_.Name.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 })
    }

    switch ($sortMode) {
        'NameDesc'    { $view = @($view | Sort-Object -Property Name -Descending) }
        'DateDesc'    { $view = @($view | Sort-Object -Property LastWriteTime -Descending) }
        'DateAsc'     { $view = @($view | Sort-Object -Property LastWriteTime) }
        'SizeDesc'    { Ensure-FolderSizesCached $view; $view = @($view | Sort-Object -Property @{Expression={ Get-FolderSizeCached $_.Path }} -Descending) }
        'SizeAsc'     { Ensure-FolderSizesCached $view; $view = @($view | Sort-Object -Property @{Expression={ Get-FolderSizeCached $_.Path }}) }
        'LibraryDesc' { $view = @($view | Sort-Object -Property @{Expression={ Test-PanelItemInLibrary $_.Name }; Descending=$true}, @{Expression='Name'}) }
        'LibraryAsc'  { $view = @($view | Sort-Object -Property @{Expression={ Test-PanelItemInLibrary $_.Name }}, @{Expression='Name'}) }
        default       { $view = @($view | Sort-Object -Property Name) }
    }

    $dateMap = @{}
    foreach ($it in $data) { $dateMap[[string]$it.Name] = $it.LastWriteTime }
    if ($source -eq 'C') { $script:panelDateMapC = $dateMap } else { $script:panelDateMapD = $dateMap }

    $listBox.BeginUpdate()
    try {
        $listBox.Items.Clear()
        foreach ($it in $view) {
            $listBox.Items.Add($it.Name) | Out-Null
            if ($selectedNames -contains $it.Name) {
                $listBox.SetSelected($listBox.Items.Count - 1, $true)
            }
        }
    } finally { $listBox.EndUpdate() }

    # Папки на диске есть (иначе список пуст по другой причине — папка ещё не
    # выбрана, это уже решает Refresh-Panels, сюда мы не лезем): показываем
    # либо сам список, либо "ничего не найдено", смотря что дал текущий поиск.
    $emptyLabel = if ($source -eq 'C') { $lblEmptyC } else { $lblEmptyD }
    if ($data.Count -gt 0) {
        try {
            if ($view.Count -eq 0) {
                $emptyLabel.Text = (T 'nothing_found' @($search))
                $emptyLabel.Visible = $true
                $listBox.Visible = $false
            } else {
                $emptyLabel.Visible = $false
                $listBox.Visible = $true
            }
        } catch {}
    }
    try { Update-MainLibraryButtonState } catch {}
    try { Update-SortHeaderUI $source } catch {}
}

function Refresh-Panels {
    # 1. Запоминаем имя выделенной игры на левой и правой панели перед очисткой.
    # Поиск и сортировку (панель, текст, режим) НЕ сбрасываем — «Обновить»
    # перечитывает диск, но не должен сбрасывать то, что пользователь ввёл
    # в строку поиска или выбрал в сортировке.
    $selectedNameC = $null; $selectedNameD = $null
    if ($listBoxC.SelectedItem -ne $null) { $selectedNameC = Clean-GameName $listBoxC.SelectedItem.ToString() }
    if ($listBoxD.SelectedItem -ne $null) { $selectedNameD = Clean-GameName $listBoxD.SelectedItem.ToString() }

    $listBoxC.Items.Clear(); $listBoxD.Items.Clear()
    # ГАЛОЧКИ (checkedC/checkedD) больше НЕ чистятся здесь безусловно.
    # Раньше Refresh-Panels вызывался в т.ч. просто при закрытии карточки игры
    # (открытой одиночным кликом по строке, без всякого сохранения) — и это
    # обнуляло весь пакетный выбор пользователя. Теперь отметки переживают
    # перечитывание диска; актуальность (что папка не пропала) проверяется
    # ниже, после того как $script:panelDataC/D снова заполнены с диска —
    # см. фильтрацию в конце функции. Явная очистка отметок, когда она
    # действительно нужна (после переноса/добавления выбранных игр или по
    # нажатию кнопки "Обновить"), делается в местах вызова, а не тут.
    $script:panelDataC = @()
    $script:panelDataD = @()

    # 2. Обе панели равноправны: каждая содержит обычную выбранную пользователем
    # папку. Нет основной/дополнительной папки и нет зависимости порядка выбора.
    $hasD = (-not [string]::IsNullOrWhiteSpace($global:dirD)) -and (Test-Path -LiteralPath $global:dirD -PathType Container)
    $hasC = (-not [string]::IsNullOrWhiteSpace($global:dirC)) -and (Test-Path -LiteralPath $global:dirC -PathType Container)

    $btnSelectC.Visible = $true
    $btnSelectD.Visible = $true
    $lblC.Visible = $true
    $lblD.Visible = $true
    $lblPathC.Visible = $true
    $lblPathD.Visible = $true

    if ($hasC) {
        try {
            $rtC = [System.IO.Path]::GetPathRoot($global:dirC).Substring(0,2)
            $driveC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$rtC'" -ErrorAction SilentlyContinue
            $lblC.Text = if ($driveC -ne $null) { (T 'panel_free' @((T 'panel_extra'), ([string][Math]::Round($driveC.FreeSpace / 1GB, 2)), (T 'unit_gb'))) } else { (T 'panel_extra') }
        } catch { $lblC.Text = (T 'panel_extra') }
        $lblPathC.Text = (T 'path_prefix') + $global:dirC
        $lblEmptyC.Visible = $false
        $listBoxC.Visible = $true
    } else {
        $lblC.Text = (T 'panel_extra')
        $lblPathC.Text = ''
        $lblEmptyC.Text = (T 'empty_extra')
        $listBoxC.Visible = $false
        $lblEmptyC.Visible = $true
    }

    if ($hasD) {
        try {
            $rtD = [System.IO.Path]::GetPathRoot($global:dirD).Substring(0,2)
            $driveD = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$rtD'" -ErrorAction SilentlyContinue
            $lblD.Text = if ($driveD -ne $null) { (T 'panel_free' @((T 'panel_main'), ([string][Math]::Round($driveD.FreeSpace / 1GB, 2)), (T 'unit_gb'))) } else { (T 'panel_main') }
        } catch { $lblD.Text = (T 'panel_main') }
        $lblPathD.Text = (T 'path_prefix') + $global:dirD
        $lblEmptyD.Visible = $false
        $listBoxD.Visible = $true
    } else {
        $lblD.Text = (T 'panel_main')
        $lblPathD.Text = ''
        $lblEmptyD.Text = (T 'empty_main')
        $listBoxD.Visible = $false
        $lblEmptyD.Visible = $true
    }

    $foldersReady = $hasC -and $hasD
    $global:foldersReady = $foldersReady
    try { Update-MainLibraryButtonState } catch {}
    
    $global:installedSteamGames.Clear()
    
    $steamPathProperty = Get-ConfiguredSteamExePath
    # Множество ShortcutId (appid), реально присутствующих в shortcuts.vdf прямо
    # сейчас. Собираем его тут же, попутно с обычным сканированием библиотеки —
    # отдельного прохода по файлу не требуется. Используется ниже, чтобы почистить
    # cover_sources от JSON-файлов игр, которых больше нет в Steam (см.
    # Remove-OrphanedCoverSourcesMetadata).
    $liveShortcutIds = @{}
    $shortcutsScanOk = $false
    if (-not [string]::IsNullOrEmpty($steamPathProperty)) {
        $steamPath = Get-ConfiguredSteamInstallPath
        $userDataPath = Get-ConfiguredSteamUserDataPath
        
        # ИСТОЧНИК 1: нестимовские ярлыки (shortcuts.vdf) — например, добавленные
        # этой же программой. РАНЬШЕ имя игры "угадывалось" по третьему по счёту
        # сегменту пути StartDir — это давало сбой при любой другой глубине
        # вложенности папок. Затем стали брать поле AppName — но его пользователь
        # может переименовать прямо в Steam (это лишь отображаемое имя), и тогда
        # оно перестаёт совпадать с именем папки на диске. Поэтому теперь берём
        # ВСЕ доступные источники сразу:
        #  1) AppName — для случаев, когда он совпадает с именем папки;
        #  2) Exe и StartDir, сопоставленные с известными корнями $dirC/$dirD —
        #     находим, какая именно подпапка SSD- или HDD-библиотеки является
        #     началом этого пути (см. Get-TopLevelFolderUnderRoot). Это работает
        #     даже если .exe лежит на 3-4 уровня глубже (Binaries\Win64\...) и
        #     совершенно не зависит от того, как называется сама игра.
        if (Test-Path $userDataPath) {
            # Раз мы дошли до реального сканирования shortcuts.vdf (файл userdata
            # найден и доступен), результат можно считать достоверным — даже если
            # ни одного shortcuts.vdf не нашлось (пустая библиотека нестимовских игр).
            $shortcutsScanOk = $true
            Get-ChildItem -Path $userDataPath -Filter "shortcuts.vdf" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
                    if ($bytes.Length -gt 0) {
                        $shortcutsNode = Get-ShortcutsNode $bytes
                        if ($shortcutsNode -ne $null) {
                            foreach ($entry in $shortcutsNode.Body.Children) {
                                if ($entry.Type -ne 0x00) { continue }

                                # ShortcutId — это appid записи, тот же ID, которым именуются
                                # файлы метаданных обложек в $global:coverSourcesDir (см.
                                # Get-CoverSourcesMetadataPath). Запоминаем как "живой".
                                $appidField = $entry.Body.Children | Where-Object { $_.Key -eq "appid" } | Select-Object -First 1
                                if ($appidField -ne $null -and -not [string]::IsNullOrEmpty([string]$appidField.Value)) {
                                    $liveShortcutIds[[string]$appidField.Value] = $true
                                }

                                $appNameField = $entry.Body.Children | Where-Object { $_.Key -eq "AppName" } | Select-Object -First 1
                                if ($appNameField -ne $null) {
                                    $normalizedAppName = Get-NormalizedGameKey $appNameField.Value
                                    if (-not [string]::IsNullOrEmpty($normalizedAppName)) {
                                        $global:installedSteamGames[$normalizedAppName] = $true
                                    }
                                }

                                $exeField = $entry.Body.Children | Where-Object { $_.Key -eq "Exe" } | Select-Object -First 1
                                $startDirField = $entry.Body.Children | Where-Object { $_.Key -eq "StartDir" } | Select-Object -First 1
                                foreach ($pathField in @($exeField, $startDirField)) {
                                    if ($pathField -eq $null -or [string]::IsNullOrEmpty($pathField.Value)) { continue }
                                    foreach ($rootPath in @($global:dirC, $global:dirD)) {
                                        $topFolder = Get-TopLevelFolderUnderRoot $pathField.Value $rootPath
                                        if (-not [string]::IsNullOrEmpty($topFolder)) {
                                            $global:installedSteamGames[(Get-NormalizedGameKey $topFolder)] = $true
                                        }
                                    }
                                }
                            }
                        }
                    }
                } catch {}
            }
        }
    }

    # Метаданные источников обложек (cover_sources\<ShortcutId>.json) переживают
    # удаление игры из Steam: сам Steam ничего не знает про эти файлы и не может
    # их подчистить. Раз сканирование shortcuts.vdf выше прошло успешно, у нас
    # есть достоверный список ShortcutId, которые реально есть в библиотеке
    # прямо сейчас — всё остальное в cover_sources оставлено удалённой игрой.
    if ($shortcutsScanOk) { Remove-OrphanedCoverSourcesMetadata $liveShortcutIds }

    if ($hasC -and $hasD) {
        Get-ChildItem -Path $global:dirC -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $fName = $_.Name
            if ($global:hiddenGames.ContainsKey((Get-HiddenGameKey 'C' $fName))) { return }
            $script:panelDataC += [PSCustomObject]@{ Name = $fName; Path = $_.FullName; LastWriteTime = $_.LastWriteTime }
        }
    }

    if ($hasD) {
        Get-ChildItem -Path $global:dirD -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            if ([string]::IsNullOrEmpty($_.LinkType)) {
                $fName = $_.Name
                if ($global:hiddenGames.ContainsKey((Get-HiddenGameKey 'D' $fName))) { return }
                $script:panelDataD += [PSCustomObject]@{ Name = $fName; Path = $_.FullName; LastWriteTime = $_.LastWriteTime }
            }
        }
    }

    # Строим сами списки (с учётом текущего поиска/сортировки панели) и
    # восстанавливаем выделение по именам, запомненным в начале функции.
    Apply-PanelView 'C' (@($selectedNameC) | Where-Object { $_ -ne $null })
    Apply-PanelView 'D' (@($selectedNameD) | Where-Object { $_ -ne $null })

    # Отметки, переживающие перечитывание диска (см. комментарий выше),
    # подчищаем только от того, чего реально больше нет в списке (папку
    # удалили/переименовали/скрыли) — остальные галочки остаются как были.
    $namesC = @{}; foreach ($it in $script:panelDataC) { $namesC[$it.Name] = $true }
    $namesD = @{}; foreach ($it in $script:panelDataD) { $namesD[$it.Name] = $true }
    foreach ($k in @($global:checkedC.Keys)) { if (-not $namesC.ContainsKey($k)) { $global:checkedC.Remove($k) | Out-Null } }
    foreach ($k in @($global:checkedD.Keys)) { if (-not $namesD.ContainsKey($k)) { $global:checkedD.Remove($k) | Out-Null } }

    try { Update-MainLibraryButtonState } catch {}

}

function Show-ExeSelectionDialog ($exeList, $rootPath, $gameName) {
    $dialog = New-Object System.Windows.Forms.Form; $dialog.Text = (T 'exe_dlg_title' @($gameName)); $dialog.Size = "640, 400"; $dialog.StartPosition = "CenterParent"; $dialog.FormBorderStyle = "FixedDialog"; $dialog.MaximizeBox = $false; $dialog.MinimizeBox = $false
    $lbl = New-Object System.Windows.Forms.Label; $lbl.Text = (T 'exe_dlg_hint'); $lbl.Location = "15, 15"; $lbl.Size = "590, 20"; $lbl.Font = New-Object System.Drawing.Font("Arial", 9.5, [System.Drawing.FontStyle]::Bold); $dialog.Controls.Add($lbl)

    # Значки реального exe (а не абстрактный список путей) помогают сразу
    # отличить настоящую игру от служебных утилит — у игр, как правило,
    # свой уникальный значок, а у редистрибутивов/лаунчеров движка — типовой.
    $imageList = New-Object System.Windows.Forms.ImageList
    $imageList.ImageSize = New-Object System.Drawing.Size(28, 28)
    $imageList.ColorDepth = [System.Windows.Forms.ColorDepth]::Depth32Bit

    $lv = New-Object System.Windows.Forms.ListView
    $lv.Location = "15, 45"; $lv.Size = "590, 245"
    $lv.View = [System.Windows.Forms.View]::Details
    $lv.FullRowSelect = $true; $lv.MultiSelect = $false; $lv.HideSelection = $false
    $lv.SmallImageList = $imageList
    $lv.Columns.Add((T 'exe_dlg_col'), 555) | Out-Null
    $lv.Font = New-Object System.Drawing.Font("Consolas", 9.5)

    for ($i = 0; $i -lt $exeList.Count; $i++) {
        $exe = $exeList[$i]
        $relativePath = $exe.FullName.Substring($rootPath.Length); if (-not $relativePath.StartsWith("")) { $relativePath = "" + $relativePath }
        $imgKey = "icon$i"
        try {
            $ico = [System.Drawing.Icon]::ExtractAssociatedIcon($exe.FullName)
            if ($ico -ne $null) { $imageList.Images.Add($imgKey, $ico) }
        } catch {}
        $lvItem = New-Object System.Windows.Forms.ListViewItem
        $lvItem.Text = [string]$relativePath
        if ($imageList.Images.ContainsKey($imgKey)) { $lvItem.ImageKey = $imgKey }
        $lv.Items.Add($lvItem) | Out-Null
    }
    if ($lv.Items.Count -gt 0) { $lv.Items[0].Selected = $true }
    $dialog.Controls.Add($lv)

    $btn = New-Object System.Windows.Forms.Button; $btn.Text = (T 'exe_dlg_ok'); $btn.Location = "250, 300"; $btn.Size = "140, 35"; $btn.DialogResult = "OK"; $dialog.Controls.Add($btn); $dialog.AcceptButton = $btn
    if ($dialog.ShowDialog() -eq "OK" -and $lv.SelectedIndices.Count -gt 0) { return $exeList[$lv.SelectedIndices[0]] }
    return $null
}

# ===================== ПОИСК/РЕДАКТИРОВАНИЕ СУЩЕСТВУЮЩЕГО ЯРЛЫКА =====================
# $exePath (необязательный) — точное совпадение по пути к exe. Нужен проверке
# дубликатов при добавлении: там $gamePath — это папка exe (например ...\bin), а не
# корень игры, и сравнение по имени последней папки давало ложные "игра уже есть".
function Find-SteamShortcutRecord ($gameName, $gamePath = $null, $exePath = $null) {
    $steamPath = Get-ConfiguredSteamInstallPath
    $userDataPath = Get-ConfiguredSteamUserDataPath
    if (-not (Test-Path $userDataPath)) { return $null }

    $targetNameKey = Get-NormalizedGameKey $gameName
    $targetFolderKey = if (-not [string]::IsNullOrEmpty($gamePath)) {
        Get-NormalizedGameKey ([System.IO.Path]::GetFileName($gamePath.TrimEnd('\')))
    } else { "" }

    $pathMatch = $null
    foreach ($shortcutsFile in (Get-ChildItem -Path $userDataPath -Filter "shortcuts.vdf" -Recurse -File -ErrorAction SilentlyContinue)) {
        try {
            $bytes = [System.IO.File]::ReadAllBytes($shortcutsFile.FullName)
            if ($bytes.Length -eq 0) { continue }
            $shortcutsNode = Get-ShortcutsNode $bytes
            if ($shortcutsNode -eq $null) { continue }

            foreach ($entry in $shortcutsNode.Body.Children) {
                if ($entry.Type -ne 0x00) { continue }

                $fields = @{}
                foreach ($field in $entry.Body.Children) {
                    if ($field.Type -eq 0x01 -or $field.Type -eq 0x02) { $fields[$field.Key] = $field }
                }

                $appName = if ($fields.ContainsKey("AppName")) { [string]$fields["AppName"].Value } else { "" }
                $exe = if ($fields.ContainsKey("Exe")) { [string]$fields["Exe"].Value } else { "" }
                $startDir = if ($fields.ContainsKey("StartDir")) { [string]$fields["StartDir"].Value } else { "" }
                $launchOptions = if ($fields.ContainsKey("LaunchOptions")) { [string]$fields["LaunchOptions"].Value } else { "" }
                $cleanExe = $exe.Trim('"')
                $cleanStart = $startDir.Trim('"')
                $entryId = if ($fields.ContainsKey("appid")) { [string]$fields["appid"].Value } else { "" }

                $record = [PSCustomObject]@{
                    FilePath=[string]$shortcutsFile.FullName
                    UserDataDir=[string]$shortcutsFile.Directory.Parent.FullName
                    Entry=$entry
                    ShortcutId=$entryId
                    AppName=$appName
                    Exe=$cleanExe
                    StartDir=$cleanStart
                    LaunchOptions=$launchOptions
                }

                if (-not [string]::IsNullOrEmpty($targetNameKey) -and
                    (Get-NormalizedGameKey $appName) -eq $targetNameKey) {
                    return $record
                }

                if (-not [string]::IsNullOrEmpty($exePath) -and -not [string]::IsNullOrEmpty($cleanExe) -and
                    [string]::Equals($cleanExe, ([string]$exePath).Trim('"'), [System.StringComparison]::OrdinalIgnoreCase)) {
                    return $record
                }

                if (-not [string]::IsNullOrEmpty($targetFolderKey)) {
                    $exeFolderKey = ""; $startFolderKey = ""
                    try { $exeFolderKey = Get-NormalizedGameKey ([System.IO.Path]::GetFileName([System.IO.Path]::GetDirectoryName($cleanExe))) } catch {}
                    try { $startFolderKey = Get-NormalizedGameKey ([System.IO.Path]::GetFileName($cleanStart.TrimEnd('\'))) } catch {}
                    if ($exeFolderKey -eq $targetFolderKey -or $startFolderKey -eq $targetFolderKey) {
                        $pathMatch = $record
                    } else {
                        try {
                            $gamePrefix = $gamePath.TrimEnd('\') + '\'
                            if ($cleanExe -and $cleanExe.StartsWith($gamePrefix,[System.StringComparison]::OrdinalIgnoreCase)) { $pathMatch=$record }
                            elseif ($cleanStart -and $cleanStart.StartsWith($gamePrefix,[System.StringComparison]::OrdinalIgnoreCase)) { $pathMatch=$record }
                        } catch {}
                    }
                }
            }
        } catch {}
    }
    return $pathMatch
}

function Test-GameAlreadyInSteamLibrary ($gameName, $gamePath = $null) {
    if (Find-SteamShortcutRecord $gameName $gamePath) { return $true }
    $key = Get-NormalizedGameKey $gameName
    if ($key -and $global:installedSteamGames.ContainsKey($key)) { return $true }
    if ($gamePath) {
        try {
            $folderKey = Get-NormalizedGameKey ([System.IO.Path]::GetFileName($gamePath.TrimEnd('\')))
            if ($folderKey -and $global:installedSteamGames.ContainsKey($folderKey)) { return $true }
        } catch {}
    }
    return $false
}

function Set-VdfStringField ($entry, $key, $value) {
    $field = $entry.Body.Children | Where-Object { $_.Key -eq $key } | Select-Object -First 1
    if ($field -ne $null) {
        if ($field.Type -ne 0x01) { throw (T 'vdf_bad_type_key' @($key)) }
        $field.Value = [string]$value
        return
    }
    $entry.Body.Children.Add([PSCustomObject]@{Key=$key;Type=0x01;Value=[string]$value})
}

function Write-VdfChildrenBytes ($children) {
    $out = New-Object System.Collections.Generic.List[byte]
    foreach ($child in $children) {
        if ($child.Type -eq 0x00) {
            $out.Add(0x00)
            $out.AddRange([byte[]][System.Text.Encoding]::UTF8.GetBytes([string]$child.Key))
            $out.Add(0x00)
            $out.AddRange([byte[]](Write-VdfChildrenBytes $child.Body.Children))
            $out.Add(0x08)
        } elseif ($child.Type -eq 0x01) {
            $out.Add(0x01)
            $out.AddRange([byte[]][System.Text.Encoding]::UTF8.GetBytes([string]$child.Key))
            $out.Add(0x00)
            $out.AddRange([byte[]][System.Text.Encoding]::UTF8.GetBytes([string]$child.Value))
            $out.Add(0x00)
        } elseif ($child.Type -eq 0x02) {
            $out.Add(0x02)
            $out.AddRange([byte[]][System.Text.Encoding]::UTF8.GetBytes([string]$child.Key))
            $out.Add(0x00)
            $out.AddRange([byte[]][BitConverter]::GetBytes([uint32]$child.Value))
        } else {
            throw (T 'vdf_bad_type' @(([int]$child.Type).ToString('X2')))
        }
    }
    # БАГ-ФИКС: "return $out" разворачивает List[byte] в отдельные элементы
    # потока вывода PowerShell. Для непустых узлов это случайно давало верный
    # массив байт, но для узла без единого дочернего элемента (например,
    # почти всегда пустой объект "tags") в конвейер попадало НОЛЬ элементов,
    # и вызывающий код получал $null вместо пустого массива байт. Дальше
    # "$out.AddRange($null)" падал с "Значение не может быть неопределенным",
    # редактирование карточки не сохранялось, и окно не закрывалось.
    # Унарная запятая заставляет PowerShell вернуть ровно один объект —
    # массив байт, даже если он пустой.
    return ,$out.ToArray()
}

function Write-VdfFileBytes ($rootChildren) {
    $out = New-Object System.Collections.Generic.List[byte]
    $out.AddRange([byte[]](Write-VdfChildrenBytes $rootChildren))
    $out.Add(0x08)
    return ,$out.ToArray()
}

function Update-ExistingSteamShortcut ($shortcutRecord, $newName, $newExePath, $newStartDir, $newLaunchOptions) {
    if ($shortcutRecord -eq $null) { $global:lastShortcutError=(T 'sc_not_found'); return $null }
    try {
        $filePath=[string]$shortcutRecord.FilePath
        if (-not (Test-Path $filePath)) { throw (T 'sc_file_missing' @($filePath)) }

        $bytes=[System.IO.File]::ReadAllBytes($filePath)
        $root=Read-VdfObjectBody $bytes 0
        $shortcutsNode=$root.Children | Where-Object { $_.Key -eq "shortcuts" } | Select-Object -First 1
        if ($shortcutsNode -eq $null) { throw (T 'sc_no_node') }

        $targetEntry=$null
        foreach($entry in $shortcutsNode.Body.Children){
            if($entry.Type -ne 0x00){continue}
            $appidField=$entry.Body.Children | Where-Object { $_.Key -eq "appid" } | Select-Object -First 1
            if($appidField -ne $null -and [string]$appidField.Value -eq [string]$shortcutRecord.ShortcutId){$targetEntry=$entry;break}
        }
        if($targetEntry -eq $null){throw (T 'sc_target_gone')}

        Set-VdfStringField $targetEntry "AppName" $newName
        Set-VdfStringField $targetEntry "Exe" ('"' + [string]$newExePath + '"')
        Set-VdfStringField $targetEntry "StartDir" ('"' + [string]$newStartDir + '"')
        Set-VdfStringField $targetEntry "LaunchOptions" ([string]$newLaunchOptions)

        $iconField=$targetEntry.Body.Children | Where-Object { $_.Key -eq "icon" } | Select-Object -First 1
        if($iconField -ne $null -and $iconField.Type -eq 0x01){$iconField.Value=""}

        [System.IO.File]::WriteAllBytes($filePath,(Write-VdfFileBytes $root.Children))
        Save-Configuration
        return [string]$shortcutRecord.ShortcutId
    } catch {
        $global:lastShortcutError=$_.Exception.Message
        return $null
    }
}

function Copy-ExistingShortcutCoversToTemp ($shortcutRecord) {
    if ($shortcutRecord -eq $null) { return $false }
    $shortcutId=[string]$shortcutRecord.ShortcutId
    if ([string]::IsNullOrWhiteSpace($shortcutId)) { return $false }

    if(Test-Path $global:tempCovers){Remove-Item $global:tempCovers -Recurse -Force -ErrorAction SilentlyContinue}
    if(-not (Test-Path $global:tempCovers)){New-Item -ItemType Directory -Path $global:tempCovers -Force | Out-Null}

    $userDataDir=[string]$shortcutRecord.UserDataDir
    if([string]::IsNullOrWhiteSpace($userDataDir) -or -not (Test-Path $userDataDir)){
        return $false
    }

    $gridDir=Join-Path $userDataDir "config\grid"
    if(-not (Test-Path $gridDir)){return $false}

    $copied=$false
    $pairs=@(
        @{Src=($shortcutId+"p.jpg");Dst="temp_p.jpg"},
        @{Src=($shortcutId+"_hero.jpg");Dst="temp_hero.jpg"},
        @{Src=($shortcutId+"_logo.png");Dst="temp_logo.png"},
        @{Src=($shortcutId+".jpg");Dst="temp_header.jpg"}
    )
    foreach($pair in $pairs){
        $srcFile=Join-Path $gridDir $pair.Src
        $dstFile=Join-Path $global:tempCovers $pair.Dst
        if(Test-Path $srcFile){
            try{Copy-Item $srcFile $dstFile -Force;$copied=$true}catch{}
        }
    }
    return $copied
}

function Save-ExistingShortcutCoversToGrid ($shortcutRecord) {
    if ($shortcutRecord -eq $null) { return $false }
    $shortcutId=[string]$shortcutRecord.ShortcutId
    if ([string]::IsNullOrWhiteSpace($shortcutId)) { return $false }

    $userDataDir=[string]$shortcutRecord.UserDataDir
    if([string]::IsNullOrWhiteSpace($userDataDir) -or -not (Test-Path $userDataDir)){return $false}

    $gridDir=Join-Path $userDataDir "config\grid"
    if(-not (Test-Path $gridDir)){New-Item -ItemType Directory -Path $gridDir -Force | Out-Null}

    $map=@(
        @{Temp="temp_p.jpg";Dest=($shortcutId+"p.jpg")},
        @{Temp="temp_hero.jpg";Dest=($shortcutId+"_hero.jpg")},
        @{Temp="temp_logo.png";Dest=($shortcutId+"_logo.png")},
        @{Temp="temp_header.jpg";Dest=($shortcutId+".jpg")}
    )
    $changed=$false
    foreach($item in $map){
        $src=Join-Path $global:tempCovers $item.Temp
        $dst=Join-Path $gridDir $item.Dest
        if(Test-Path $src){
            try{
                Copy-Item $src $dst -Force -ErrorAction Stop
                $changed=$true
            }catch{}
        }
    }
    return $changed
}

function Add-ShortcutToSteam ($gameName, $exePath, $startDir, $launchOptions = "") {
    # БАГ-ФИКС: раньше здесь передавался $startDir. Из карточки игры это папка
    # выбранного exe (например "...\Baldurs Gate 3\bin"), и проверка по имени
    # последней папки принимала за дубликат ЛЮБОЙ ярлык, чей exe лежит в папке с
    # таким же общим именем (bin, Win64, Binaries...). Дубликат — это ярлык с тем
    # же названием или с тем же exe.
    $existingShortcut = Find-SteamShortcutRecord $gameName $null $exePath
    if ($existingShortcut -ne $null) {
        $global:lastShortcutError = (T 'sc_exists' @($gameName))
        return $null
    }
    $steamPath = Get-ConfiguredSteamInstallPath
    $userDataPath = Get-ConfiguredSteamUserDataPath
    if (-not (Test-Path $userDataPath)) { $global:lastShortcutError = (T 'sc_userdata_missing' @($userDataPath)); return $null }
    $success = $false; $resultId = $null
    
    $exePathNormalized = $exePath.ToUpper(); $startDirNormalized = $startDir.ToUpper()
    $global:lastShortcutError = $null
    Get-ConfiguredSteamProfileDirectories | ForEach-Object {
        $configDir = Join-Path $_.FullName "config"
        if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
        $shortcutsFile = Join-Path $configDir "shortcuts.vdf"

        # РАНЬШЕ: если shortcuts.vdf ещё не существовал (у пользователя ни разу не было
        # нестимовского ярлыка на этом профиле), весь блок ниже просто пропускался —
        # игра молча НЕ добавлялась, а Steam, уже убитый через taskkill чуть выше,
        # не перезапускался, потому что код перезапуска сидит внутри "if ($newShortcutId)".
        # Именно это выглядело как "игра не добавляется, а Steam не запускается".
        # Теперь при отсутствии файла мы создаём валидный shortcuts.vdf с нуля.
        $fileExisted = Test-Path $shortcutsFile

        try {
            $bName = [System.Text.Encoding]::UTF8.GetBytes($gameName)
            $bExe = [System.Text.Encoding]::UTF8.GetBytes("`"$exePathNormalized`"")
            $bDir = [System.Text.Encoding]::UTF8.GetBytes("`"$startDirNormalized`"")
            $bLaunchOptions = [System.Text.Encoding]::UTF8.GetBytes([string]$launchOptions)

            # РАНЬШЕ ЭТОГО ПОЛЯ НЕ БЫЛО ВООБЩЕ. Без него Steam при чтении файла
            # сам придумывает id для ярлыка (неизвестным нам способом), из-за чего
            # обложки, посчитанные нашей формулой, не совпадали с тем, что ждёт Steam.
            # Теперь мы пишем id САМИ — Steam обязан использовать именно его.
            $shortcutIdValue = [uint32](Get-SteamShortcutID $exePathNormalized $gameName)
            $bAppId = [BitConverter]::GetBytes($shortcutIdValue)

            $bytes = $null; $insertPos = 0
            if ($fileExisted) {
                $bytes = [System.IO.File]::ReadAllBytes($shortcutsFile)
                $shortcutsNode = Get-ShortcutsNode $bytes
                if ($shortcutsNode -eq $null) { throw (T 'sc_node_corrupt') }

                $maxIndex = -1
                foreach ($c in $shortcutsNode.Body.Children) {
                    if ($c.Key -match '^\d+$') { $v = [int]$c.Key; if ($v -gt $maxIndex) { $maxIndex = $v } }
                }
                $nextIndexValue = $maxIndex + 1
                $insertPos = $shortcutsNode.Body.EndPos
            } else {
                $nextIndexValue = 0
            }
            $bIndex = [System.Text.Encoding]::UTF8.GetBytes($nextIndexValue.ToString())

            $fEntry = New-Object System.Collections.Generic.List[byte]
            $fEntry.Add(0x00); $fEntry.AddRange([byte[]]$bIndex); $fEntry.Add(0x00)

            # appid (должно идти одним из первых полей в записи)
            $fEntry.Add(0x02); $fEntry.AddRange([byte[]]([System.Text.Encoding]::UTF8.GetBytes("appid"))); $fEntry.Add(0x00); $fEntry.AddRange([byte[]]$bAppId)

            # AppName
            $fEntry.Add(0x01); $fEntry.AddRange([byte[]]([System.Text.Encoding]::UTF8.GetBytes("AppName"))); $fEntry.Add(0x00); $fEntry.AddRange([byte[]]$bName); $fEntry.Add(0x00)

            # Exe
            $fEntry.Add(0x01); $fEntry.AddRange([byte[]]([System.Text.Encoding]::UTF8.GetBytes("Exe"))); $fEntry.Add(0x00); $fEntry.AddRange([byte[]]$bExe); $fEntry.Add(0x00)

            # StartDir
            $fEntry.Add(0x01); $fEntry.AddRange([byte[]]([System.Text.Encoding]::UTF8.GetBytes("StartDir"))); $fEntry.Add(0x00); $fEntry.AddRange([byte[]]$bDir); $fEntry.Add(0x00)

            # LaunchOptions — параметры запуска из карточки.
            $fEntry.Add(0x01); $fEntry.AddRange([byte[]]([System.Text.Encoding]::UTF8.GetBytes("LaunchOptions"))); $fEntry.Add(0x00); $fEntry.AddRange([byte[]]$bLaunchOptions); $fEntry.Add(0x00)

            # icon
            $fEntry.Add(0x01); $fEntry.AddRange([byte[]]([System.Text.Encoding]::UTF8.GetBytes("icon"))); $fEntry.Add(0x00); $fEntry.Add(0x00)

            # IsHidden
            $fEntry.Add(0x02); $fEntry.AddRange([byte[]]([System.Text.Encoding]::UTF8.GetBytes("IsHidden"))); $fEntry.Add(0x00); $fEntry.AddRange([byte[]]@(0,0,0,0))

            # AllowDesktopConfig
            $fEntry.Add(0x02); $fEntry.AddRange([byte[]]([System.Text.Encoding]::UTF8.GetBytes("AllowDesktopConfig"))); $fEntry.Add(0x00); $fEntry.AddRange([byte[]]@(1,0,0,0))

            # AllowOverlay
            $fEntry.Add(0x02); $fEntry.AddRange([byte[]]([System.Text.Encoding]::UTF8.GetBytes("AllowOverlay"))); $fEntry.Add(0x00); $fEntry.AddRange([byte[]]@(1,0,0,0))

            # tags (пустой вложенный объект)
            $fEntry.Add(0x00); $fEntry.AddRange([byte[]]([System.Text.Encoding]::UTF8.GetBytes("tags"))); $fEntry.Add(0x00); $fEntry.Add(0x08)
            $fEntry.Add(0x08)   # закрывает саму запись ярлыка

            $newBytes = New-Object System.Collections.Generic.List[byte]
            if ($fileExisted) {
                # Вставляем новую запись РОВНО перед байтом, закрывающим объект "shortcuts"
                # (позиция вычислена честным разбором дерева, а не догадкой по хвосту файла),
                # и переносим весь остальной файл как есть, без изменений.
                for ($i = 0; $i -lt $insertPos; $i++) { $newBytes.Add($bytes[$i]) }
                $newBytes.AddRange([byte[]]$fEntry.ToArray())
                for ($i = $insertPos; $i -lt $bytes.Length; $i++) { $newBytes.Add($bytes[$i]) }
            } else {
                # Файла не было — собираем минимальный валидный shortcuts.vdf с нуля.
                $newBytes.Add(0x00)
                $newBytes.AddRange([byte[]]([System.Text.Encoding]::UTF8.GetBytes("shortcuts")))
                $newBytes.Add(0x00)
                $newBytes.AddRange([byte[]]$fEntry.ToArray())
                $newBytes.Add(0x08)  # закрывает объект "shortcuts"
                $newBytes.Add(0x08)  # закрывает корень файла
            }

            [System.IO.File]::WriteAllBytes($shortcutsFile, $newBytes.ToArray())
            $success = $true; $resultId = [string]$shortcutIdValue
        } catch {
            $global:lastShortcutError = $_.Exception.Message
        }
    }
    
    Save-Configuration
    
    if ($success) { return $resultId } else { return $null }
}
function Start-GameCopy ($srcPath, $dstPath, $msgTitle, $gameName, $aggregateBaseBytes = 0, $aggregateTotalBytes = 0) {
    $totalFiles = (Get-ChildItem -Path $srcPath -Recurse -File -ErrorAction SilentlyContinue).Count
    if ($totalFiles -eq 0) { $totalFiles = 1 }

    $totalSize = 0
    Get-ChildItem -Path $srcPath -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $totalSize += $_.Length }
    if ($totalSize -eq 0) { $totalSize = 1 }

    # /MT:32 на механическом HDD только вредит (случайные seek'и вместо последовательной записи)
    # и, на быстром SSD, копирует всё "залпом" быстрее, чем успевает сработать опрос прогресса —
    # отсюда и жалоба "бар почти сразу заполняется". /MT:6 — разумный баланс скорости и плавности.
    $pInfo = New-Object System.Diagnostics.ProcessStartInfo -Property @{
        FileName = "robocopy.exe"; Arguments = "`"$srcPath`" `"$dstPath`" /E /MOVE /BYTES /NJH /NJS /NC /NFL /NDL /NP /R:1 /W:1 /MT:6"
        RedirectStandardOutput = $false; UseShellExecute = $false; CreateNoWindow = $true
    }
    $proc = New-Object System.Diagnostics.Process; $proc.StartInfo = $pInfo; $proc.Start() | Out-Null
    
    $lastSize = 0
    $lastCheckTime = [DateTime]::Now

    while (-not $proc.HasExited) {
        Start-Sleep -Milliseconds 250
        [System.Windows.Forms.Application]::DoEvents()
        
        if (Test-Path $dstPath) {
            $currentSize = 0
            Get-ChildItem -Path $dstPath -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $currentSize += $_.Length }
            
            $now = [DateTime]::Now
            $timeDiff = ([DateTime]$now - [DateTime]$lastCheckTime).TotalSeconds
            if ($timeDiff -gt 0) {
                $sizeDiff = [int64]$currentSize - [int64]$lastSize
                if ($sizeDiff -lt 0) { $sizeDiff = 0 }
                $speedMB = [int][Math]::Round(($sizeDiff / 1MB) / $timeDiff)
                
                $lastSize = $currentSize
                $lastCheckTime = $now
                
                # При переносе нескольких игр этот же бар показывает ОБЩИЙ
                # прогресс всей операции, а не начинает отсчёт заново для каждой
                # папки. За основу берём суммарный объём уже завершённых игр и
                # текущий объём текущей папки.
                $currentAggregateBytes = [int64]$aggregateBaseBytes + [int64]$currentSize
                if ($aggregateTotalBytes -gt 0) {
                    $aggregatePercent = [int][Math]::Round(($currentAggregateBytes / [double]$aggregateTotalBytes) * 100)
                } else {
                    $aggregatePercent = [int][Math]::Round(($currentSize / [double]$totalSize) * 100)
                }
                $aggregatePercent = [Math]::Min(100, [Math]::Max(0, $aggregatePercent))
                $progressBarFolder.Value = $aggregatePercent
                $labelHeader.Text = (T 'st_copy_progress' @($msgTitle, $gameName, ([string]$speedMB), $aggregatePercent))
            }
        }
    }
    $proc.WaitForExit(); $proc.Dispose()
    
    # Здесь НЕ сбрасываем бар и НЕ издаём звук: при пакетном переносе
    # следующая папка должна продолжить общий прогресс, а сигнал должен
    # прозвучать только один раз после завершения всей операции.
    if ($aggregateTotalBytes -le 0) {
        $progressBarFolder.Value = 100
    } else {
        $completedAggregate = [int64]$aggregateBaseBytes + [int64]$totalSize
        $aggregateDonePercent = [int][Math]::Round(($completedAggregate / [double]$aggregateTotalBytes) * 100)
        $progressBarFolder.Value = [Math]::Min(100, [Math]::Max(0, $aggregateDonePercent))
    }
    $labelHeader.Text = (T 'st_copy_done' @($msgTitle, $gameName))
    [System.Windows.Forms.Application]::DoEvents()
}

# Временные обложки никогда не создаются рядом с EXE.
# Они живут в системном TEMP и удаляются при закрытии программы.
$global:tempCovers = Join-Path ([System.IO.Path]::GetTempPath()) "SteamCommander"
if (-not (Test-Path $global:tempCovers)) {
    New-Item -ItemType Directory -Path $global:tempCovers -Force | Out-Null
}

function Remove-TemporaryCovers {
    try {
        if (Test-Path $global:tempCovers) {
            Remove-Item -LiteralPath $global:tempCovers -Recurse -Force -ErrorAction SilentlyContinue
        }
    } catch {}
}

# Удаляет только четыре временных файла обложек текущей карточки (капсула,
# hero, header, logo). Нужна карточке игры: Add-кнопка решает, есть ли что
# копировать в grid, по НАЛИЧИЮ этих файлов в TEMP (Test-CoversValid), а не по
# тому, что показано в слотах. Без очистки при открытии карточки файлы от
# предыдущей игры (пропущенной, отменённой или оборвавшейся на ошибке)
# оставались лежать, и игра без App ID (например, фанатская, которой нет в
# Steam) получала чужие обложки, хотя в слотах было "NO COVER".
function Clear-TempCoverFiles {
    foreach ($f in @('temp_p.jpg','temp_hero.jpg','temp_header.jpg','temp_logo.png')) {
        try { Remove-Item -LiteralPath (Join-Path $global:tempCovers $f) -Force -ErrorAction SilentlyContinue } catch {}
    }
}
# ===================== ТОЧНОЕ РАЗРЕШЕНИЕ ССЫЛОК НА ОБЛОЖКИ =====================
# БАГ-ФИКС: с 2025-2026 годов часть изданий на Steam раздаёт обложки НЕ по
# старому плоскому пути ".../apps/{appid}/library_600x900.jpg", а по пути с
# уникальным хеш-префиксом файла — например
# ".../apps/2623190/b52322f78cbdc.../library_600x900_2x.jpg". Угадать такой
# путь заранее невозможно, поэтому прямое скачивание по фиксированному
# шаблону (см. Download-CoversToTemp выше) закономерно получает 404 для
# таких игр — даже если обложка у них есть и прекрасно видна в самом Steam
# (именно так вело себя реальное App ID 1712100 "Carmageddon: Rogue Shift",
# выпущенное в 2026 году).
#
# Официальный (и не требующий API-ключа) способ узнать РЕАЛЬНЫЕ ссылки —
# IStoreBrowseService/GetItems с include_assets=true: он возвращает шаблон
# asset_url_format вида "steam/apps/{appid}/${FILENAME}?t=..." и конкретные
# имена файлов (уже с нужным хеш-префиксом, если он есть) для капсулы,
# hero-фона, header и логотипа.
# Язык Steam (для локализованных обложек) по языку интерфейса из «Настроек».
function Get-SteamAssetLanguage {
    $code = [string]$global:language
    foreach ($l in @($script:languageList)) {
        if ([string]$l.Code -eq $code -and -not [string]::IsNullOrWhiteSpace([string]$l.Steam)) { return [string]$l.Steam }
    }
    return 'english'
}

function Get-AssetFilenameValue ($node, [string]$lang = 'english') {
    if ($node -eq $null) { return $null }
    if ($node -is [string]) {
        if ([string]::IsNullOrEmpty($node)) { return $null }
        return $node
    }

    $propNames = @($node.PSObject.Properties.Name)
    foreach ($sizeKey in @('image2x', 'image')) {
        if ($propNames -contains $sizeKey) {
            $sub = $node.$sizeKey
            if ($sub -is [string]) {
                if (-not [string]::IsNullOrEmpty($sub)) { return $sub }
            } elseif ($sub -ne $null) {
                $subNames = @($sub.PSObject.Properties.Name)
                # Сначала язык интерфейса, затем английский.
                if ($lang -ne 'english' -and $subNames -contains $lang -and -not [string]::IsNullOrEmpty([string]$sub.$lang)) {
                    return [string]$sub.$lang
                }
                if ($subNames -contains 'english' -and -not [string]::IsNullOrEmpty([string]$sub.english)) {
                    return [string]$sub.english
                }
                foreach ($n in $subNames) {
                    $val = $sub.$n
                    if ($val -is [string] -and -not [string]::IsNullOrEmpty($val)) { return [string]$val }
                }
            }
        }
    }
    if ($propNames -contains 'english' -and -not [string]::IsNullOrEmpty([string]$node.english)) {
        return [string]$node.english
    }
    foreach ($n in $propNames) {
        $val = $node.$n
        if ($val -is [string] -and -not [string]::IsNullOrEmpty($val)) { return [string]$val }
    }
    return $null
}

function Get-SteamAssetUrlsViaApi ($appId, [string]$lang = 'english') {
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

    # Для языка, отличного от английского, просим витрину отдать ассеты на нём
    # (если у игры есть локализованные — придут они, иначе — стандартные).
    $ctx = @{ country_code = "US" }
    if ($lang -ne 'english') { $ctx.language = $lang }
    $inputObj = @{ ids = @(@{ appid = [int]$appId }); context = $ctx; data_request = @{ include_assets = $true } }
    $inputJson = ($inputObj | ConvertTo-Json -Depth 5 -Compress)
    $url = "https://api.steampowered.com/IStoreBrowseService/GetItems/v1/?input_json=" + [System.Uri]::EscapeDataString($inputJson)

    # Пилотная неблокирующая версия: сам запрос идёт в фоновом runspace (см.
    # Invoke-BackgroundJsonRequest), а UI-поток крутит спиннер, ожидая ответ.
    $data = Invoke-BackgroundJsonRequest {
        param($u)
        try {
            return (Invoke-RestMethod -Uri $u -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -TimeoutSec 12 -ErrorAction Stop)
        } catch {
            try {
                $rawLines = curl.exe -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" $u
                $rawJson = ($rawLines -join "")
                if (-not [string]::IsNullOrWhiteSpace($rawJson)) { return ($rawJson | ConvertFrom-Json -ErrorAction Stop) }
            } catch {}
            return $null
        }
    } @($url) 15
    if ($data -eq $null -or $data.response -eq $null -or $data.response.store_items -eq $null -or $data.response.store_items.Count -eq 0) { return $null }

    $item = $data.response.store_items[0]
    $assets = $item.assets
    if ($assets -eq $null -or [string]::IsNullOrEmpty($assets.asset_url_format)) { return $null }

    $pathTemplate = [string]$assets.asset_url_format
    $assetPropNames = @($assets.PSObject.Properties.Name)

    $capsuleFile = if ($assetPropNames -contains 'library_capsule_2x') { Get-AssetFilenameValue $assets.library_capsule_2x $lang }
                   elseif ($assetPropNames -contains 'library_capsule') { Get-AssetFilenameValue $assets.library_capsule $lang }
                   else { $null }
    $heroFile = if ($assetPropNames -contains 'library_hero_2x') { Get-AssetFilenameValue $assets.library_hero_2x $lang }
                elseif ($assetPropNames -contains 'library_hero') { Get-AssetFilenameValue $assets.library_hero $lang }
                else { $null }
    $headerFile = if ($assetPropNames -contains 'header') { Get-AssetFilenameValue $assets.header $lang } else { $null }
    $logoFile = if ($assetPropNames -contains 'library_logo') { Get-AssetFilenameValue $assets.library_logo $lang }
                elseif ($assetPropNames -contains 'logo') { Get-AssetFilenameValue $assets.logo $lang }
                else { $null }

    # Steam может раздавать один и тот же asset через разные CDN-хосты.
    # Возвращаем список кандидатов, чтобы загрузчик мог попробовать второй,
    # если первый CDN временно недоступен.
    $cdnDomains = @(
        "https://shared.fastly.steamstatic.com/store_item_assets/",
        "https://shared.akamai.steamstatic.com/store_item_assets/"
    )
    $buildUrls = {
        param($filenameField)
        if ([string]::IsNullOrEmpty([string]$filenameField)) { return @() }
        return @($cdnDomains | ForEach-Object { $_ + $pathTemplate.Replace('${FILENAME}', [string]$filenameField) })
    }

    return [PSCustomObject]@{
        Capsule = & $buildUrls $capsuleFile
        Hero    = & $buildUrls $heroFile
        Header  = & $buildUrls $headerFile
        Logo    = & $buildUrls $logoFile
        Name    = [string]$item.name
    }
}

# ===================== РЕГИОНЫ (ЯЗЫКИ) ОБЛОЖЕК STEAM =====================
# Steam хранит библиотечные ассеты (капсула, hero, логотип, header) по языкам:
# в PICS это common.library_assets_full.<ассет>.image(2x).<язык>. Steam — API-имя
# языка, Short — подпись на кнопке в карточке, Name — название в списке выбора
# (на самом языке, чтобы не переводить его на каждый язык интерфейса).
$script:steamCoverLanguages = @(
    [PSCustomObject]@{ Steam='english';    Short='EN';    Name='English' },
    [PSCustomObject]@{ Steam='russian';    Short='РУ';    Name='Русский' },
    [PSCustomObject]@{ Steam='ukrainian';  Short='UK';    Name='Українська' },
    [PSCustomObject]@{ Steam='german';     Short='DE';    Name='Deutsch' },
    [PSCustomObject]@{ Steam='french';     Short='FR';    Name='Français' },
    [PSCustomObject]@{ Steam='spanish';    Short='ES';    Name='Español' },
    [PSCustomObject]@{ Steam='latam';      Short='LA';    Name='Español (Latinoamérica)' },
    [PSCustomObject]@{ Steam='brazilian';  Short='BR';    Name='Português (Brasil)' },
    [PSCustomObject]@{ Steam='portuguese'; Short='PT';    Name='Português' },
    [PSCustomObject]@{ Steam='italian';    Short='IT';    Name='Italiano' },
    [PSCustomObject]@{ Steam='polish';     Short='PL';    Name='Polski' },
    [PSCustomObject]@{ Steam='czech';      Short='CS';    Name='Čeština' },
    [PSCustomObject]@{ Steam='hungarian';  Short='HU';    Name='Magyar' },
    [PSCustomObject]@{ Steam='romanian';   Short='RO';    Name='Română' },
    [PSCustomObject]@{ Steam='bulgarian';  Short='BG';    Name='Български' },
    [PSCustomObject]@{ Steam='greek';      Short='EL';    Name='Ελληνικά' },
    [PSCustomObject]@{ Steam='turkish';    Short='TR';    Name='Türkçe' },
    [PSCustomObject]@{ Steam='dutch';      Short='NL';    Name='Nederlands' },
    [PSCustomObject]@{ Steam='swedish';    Short='SV';    Name='Svenska' },
    [PSCustomObject]@{ Steam='danish';     Short='DA';    Name='Dansk' },
    [PSCustomObject]@{ Steam='finnish';    Short='FI';    Name='Suomi' },
    [PSCustomObject]@{ Steam='norwegian';  Short='NO';    Name='Norsk' },
    [PSCustomObject]@{ Steam='schinese';   Short='ZH';    Name='简体中文' },
    [PSCustomObject]@{ Steam='tchinese';   Short='TW';    Name='繁體中文' },
    [PSCustomObject]@{ Steam='japanese';   Short='JA';    Name='日本語' },
    [PSCustomObject]@{ Steam='koreana';    Short='KO';    Name='한국어' },
    [PSCustomObject]@{ Steam='thai';       Short='TH';    Name='ไทย' },
    [PSCustomObject]@{ Steam='vietnamese'; Short='VI';    Name='Tiếng Việt' },
    [PSCustomObject]@{ Steam='arabic';     Short='AR';    Name='العربية' },
    [PSCustomObject]@{ Steam='indonesian'; Short='ID';    Name='Bahasa Indonesia' }
)

function Get-SteamLanguageInfo ([string]$steamLang) {
    $key = ([string]$steamLang).ToLowerInvariant()
    foreach ($l in $script:steamCoverLanguages) { if ([string]$l.Steam -eq $key) { return $l } }
    $short = if ($key.Length -ge 2) { $key.Substring(0,2).ToUpperInvariant() } else { $key.ToUpperInvariant() }
    return [PSCustomObject]@{ Steam=$key; Short=$short; Name=$key }
}

# Языки, на которых у игры реально есть библиотечные ассеты (объединение по
# капсуле/hero/логотипу/header). Порядок — как в таблице выше, неизвестные — в конце.
function Get-SteamPicsAvailableLanguages ($appId) {
    $common = Get-SteamPicsCommon $appId
    if ($common -eq $null -or $common.library_assets_full -eq $null) { return @() }
    $found = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($nodeName in @('library_capsule','library_hero','library_logo','library_header')) {
        $node = $common.library_assets_full.$nodeName
        if ($node -eq $null) { continue }
        foreach ($key in @('image2x','image')) {
            $img = $node.$key
            if ($img -eq $null) { continue }
            foreach ($p in @($img.PSObject.Properties)) {
                if ($p.Value -is [string] -and -not [string]::IsNullOrEmpty([string]$p.Value)) { [void]$found.Add([string]$p.Name) }
            }
        }
    }
    $ordered = @()
    foreach ($l in $script:steamCoverLanguages) { if ($found.Contains([string]$l.Steam)) { $ordered += [string]$l.Steam } }
    foreach ($n in @($found | Sort-Object)) { if ($ordered -notcontains [string]$n) { $ordered += [string]$n } }
    return @($ordered)
}

# Кэш узла common из PICS по App ID: и загрузка обложек, и кнопка выбора региона
# в карточке спрашивают одни и те же данные — второй запрос к сети не нужен.
$script:picsCommonCache = @{}
function Get-SteamPicsCommon ($appId) {
    $cacheKey = [string]$appId
    if ($script:picsCommonCache.ContainsKey($cacheKey)) { return $script:picsCommonCache[$cacheKey] }

    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

    $url  = "https://api.steamcmd.net/v1/info/$appId"
    $data = $null

    # В карточке игры не блокируем UI-поток: тянем JSON отдельным curl.exe,
    # прокачивая очередь сообщений (тот же приём, что и для картинок).
    if ($global:uiPumpDuringDownload) {
        $tmpJson = Join-Path $env:TEMP ("steamorg_pics_{0}.json" -f $appId)
        Remove-Item $tmpJson -Force -ErrorAction SilentlyContinue
        $pumped = Invoke-UiPumpingDownload $url $tmpJson 20
        if ($pumped -eq $true) {
            try { $data = (Get-Content -LiteralPath $tmpJson -Raw) | ConvertFrom-Json -ErrorAction Stop } catch { $data = $null }
        }
        Remove-Item $tmpJson -Force -ErrorAction SilentlyContinue
    }

    if ($data -eq $null) {
        try {
            $data = Invoke-RestMethod -Uri $url -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -TimeoutSec 15 -ErrorAction Stop
        } catch {
            try {
                $raw = (curl.exe -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" --connect-timeout 10 --max-time 20 $url) -join ""
                if (-not [string]::IsNullOrWhiteSpace($raw)) { $data = $raw | ConvertFrom-Json -ErrorAction Stop }
            } catch {}
        }
    }
    if ($data -eq $null -or $data.data -eq $null) { return $null }

    $appNode = $data.data.PSObject.Properties | Where-Object { $_.Name -eq [string]$appId } | Select-Object -First 1
    if ($appNode -eq $null) { return $null }
    $common = $appNode.Value.common
    if ($common -eq $null) { return $null }
    $script:picsCommonCache[$cacheKey] = $common
    return $common
}

# БАГ-ФИКС: логотип (library_logo) у современных игр не находится ни прямым
# путём .../store_item_assets/steam/apps/<appid>/logo.png (ассет лежит с
# хеш-префиксом в пути), ни через IStoreBrowseService/GetItems — в объекте
# assets этого API логотипа попросту нет (там только asset_url_format,
# main_capsule, small_capsule, header, library_capsule(_2x), library_hero(_2x)).
# Поэтому ветка "докачать логотип по API" оставалась пустой, и реально
# существующий логотип показывался в карточке как отсутствующий.
#
# Полный набор библиотечных ассетов вместе с хеш-префиксами лежит в PICS —
# в секции common.library_assets_full (это то же, что показывает SteamDB).
# Забираем оттуда и собираем прямые ссылки на CDN (по всем зеркалам).
function Get-SteamPicsAssetUrls ($appId, [string]$lang = 'english') {
    $common = Get-SteamPicsCommon $appId
    if ($common -eq $null) { return $null }

    # Из узла library_assets_full выбираем файл по приоритету языка:
    #   1) язык интерфейса программы (image2x, затем image),
    #   2) английский (image2x, затем image),
    #   3) первый непустой язык (у части игр английского варианта нет).
    # У игр без локализованных обложек язык интерфейса просто не находится и
    # берётся английский — как раньше.
    $pickFull = {
        param($node, $preferLang)
        if ($node -eq $null) { return $null }
        $langOrder = @([string]$preferLang)
        if ([string]$preferLang -ne 'english') { $langOrder += 'english' }
        foreach ($lg in $langOrder) {
            foreach ($key in @('image2x','image')) {
                $img = $node.$key
                if ($img -eq $null) { continue }
                $val = $img.$lg
                if ($val -is [string] -and -not [string]::IsNullOrEmpty($val)) { return [string]$val }
            }
        }
        foreach ($key in @('image2x','image')) {
            $img = $node.$key
            if ($img -eq $null) { continue }
            foreach ($p in @($img.PSObject.Properties)) {
                if ($p.Value -is [string] -and -not [string]::IsNullOrEmpty([string]$p.Value)) { return [string]$p.Value }
            }
        }
        return $null
    }

    $logoFile = $null; $capsuleFile = $null; $heroFile = $null; $headerFile = $null
    if ($common.library_assets_full -ne $null) {
        $logoFile    = & $pickFull $common.library_assets_full.library_logo $lang
        $capsuleFile = & $pickFull $common.library_assets_full.library_capsule $lang
        $heroFile    = & $pickFull $common.library_assets_full.library_hero $lang
        $headerFile  = & $pickFull $common.library_assets_full.library_header $lang
    }
    # Старый формат PICS (library_assets) — имена файлов без хеш-префикса.
    if ($common.library_assets -ne $null) {
        if ([string]::IsNullOrEmpty($logoFile)    -and -not [string]::IsNullOrEmpty([string]$common.library_assets.library_logo))    { $logoFile    = [string]$common.library_assets.library_logo }
        if ([string]::IsNullOrEmpty($capsuleFile) -and -not [string]::IsNullOrEmpty([string]$common.library_assets.library_capsule)) { $capsuleFile = [string]$common.library_assets.library_capsule }
        if ([string]::IsNullOrEmpty($heroFile)    -and -not [string]::IsNullOrEmpty([string]$common.library_assets.library_hero))    { $heroFile    = [string]$common.library_assets.library_hero }
    }

    # Язык, на котором ФАКТИЧЕСКИ получились ассеты: запрошенный — если он есть
    # хотя бы у одного из четырёх, иначе английский (так подписывается кнопка
    # региона в карточке).
    $effLang = 'english'
    if ($lang -ne 'english' -and $common.library_assets_full -ne $null) {
        foreach ($nodeName in @('library_capsule','library_hero','library_logo','library_header')) {
            $node = $common.library_assets_full.$nodeName
            if ($node -eq $null) { continue }
            foreach ($key in @('image2x','image')) {
                $img = $node.$key
                if ($img -eq $null) { continue }
                $v = $img.$lang
                if ($v -is [string] -and -not [string]::IsNullOrEmpty($v)) { $effLang = $lang; break }
            }
            if ($effLang -eq $lang) { break }
        }
    }

    $cdnDomains = @(
        "https://shared.fastly.steamstatic.com/store_item_assets/",
        "https://shared.akamai.steamstatic.com/store_item_assets/",
        "https://shared.cloudflare.steamstatic.com/store_item_assets/"
    )
    $buildUrls = {
        param($filenameField)
        if ([string]::IsNullOrEmpty([string]$filenameField)) { return @() }
        $rel = "steam/apps/$appId/" + ([string]$filenameField -replace '^/','')
        return @($cdnDomains | ForEach-Object { $_ + $rel })
    }

    $out = [PSCustomObject]@{
        Capsule  = & $buildUrls $capsuleFile
        Hero     = & $buildUrls $heroFile
        Header   = & $buildUrls $headerFile
        Logo     = & $buildUrls $logoFile
        Language = $effLang
    }
    if (@($out.Capsule).Count -eq 0 -and @($out.Hero).Count -eq 0 -and @($out.Header).Count -eq 0 -and @($out.Logo).Count -eq 0) { return $null }
    return $out
}

# ===================== ПОДСКАЗКА EXE ИЗ STEAM (PICS: config.launch) =====================
# У каждой игры в Steam есть запись о том, какой файл запускать (то же самое
# показывает SteamDB в разделе Configuration -> Launch Options -> Executable).
# Данные берём из того же PICS, но по обычному HTTP — через api.steamcmd.net
# (этот же сервис уже используется в Get-SteamPicsAssetUrls). Путь в записи
# указан ОТНОСИТЕЛЬНО папки установки игры, поэтому подсказка засчитывается
# только если такой файл реально существует в папке игры на диске. Это же
# служит подтверждением: если App ID определён неверно, нужного exe в папке
# просто не окажется, и программа вернётся к прежнему выбору.
$global:steamLaunchExeCache = @{}
$global:steamLaunchHintDisabledUntil = [datetime]::MinValue

# Возвращает массив относительных путей exe для Windows (в порядке записей
# launch), либо пустой массив. Результат кэшируется на сеанс по App ID.
function Get-SteamLaunchExecutables ($appId) {
    $appIdStr = [string]$appId
    if ($appIdStr -notmatch '^\d+$') { return @() }
    if ($global:steamLaunchExeCache.ContainsKey($appIdStr)) { return @($global:steamLaunchExeCache[$appIdStr]) }
    # Если сервис недавно не ответил, не заставляем ждать заново на каждой игре.
    if ((Get-Date) -lt $global:steamLaunchHintDisabledUntil) { return @() }

    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
    $url = "https://api.steamcmd.net/v1/info/$appIdStr"
    $data = Invoke-BackgroundJsonRequest {
        param($u)
        try {
            return (Invoke-RestMethod -Uri $u -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -TimeoutSec 8 -ErrorAction Stop)
        } catch {
            try {
                $rawLines = curl.exe -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" --connect-timeout 5 --max-time 8 $u
                $rawJson = ($rawLines -join "")
                if (-not [string]::IsNullOrWhiteSpace($rawJson)) { return ($rawJson | ConvertFrom-Json -ErrorAction Stop) }
            } catch {}
            return $null
        }
    } @($url) 20

    if ($data -eq $null) {
        $global:steamLaunchHintDisabledUntil = (Get-Date).AddMinutes(10)
        return @()
    }

    $found = New-Object System.Collections.Generic.List[string]
    $optionExes = New-Object System.Collections.Generic.List[string]
    try {
        $appNode = $null
        if ($data.data -ne $null) {
            $appNode = $data.data.PSObject.Properties | Where-Object { $_.Name -eq $appIdStr } | Select-Object -First 1
        }
        $launch = $null
        if ($appNode -ne $null -and $appNode.Value -ne $null -and $appNode.Value.config -ne $null) { $launch = $appNode.Value.config.launch }
        if ($launch -ne $null) {
            $launchItems = @()
            if ($launch -is [System.Array]) {
                $launchItems = @($launch)
            } else {
                $launchItems = @($launch.PSObject.Properties |
                    Sort-Object { $n = 0; if ([int]::TryParse($_.Name, [ref]$n)) { $n } else { [int]::MaxValue } } |
                    ForEach-Object { $_.Value })
            }
            foreach ($l in $launchItems) {
                if ($l -eq $null) { continue }
                $exe = [string]$l.executable
                if ([string]::IsNullOrWhiteSpace($exe)) { continue }
                # Основной запуск (default/none) и варианты выбора при запуске
                # (option1, option2...) — у некоторых игр прямой exe лежит именно
                # среди вариантов, а по умолчанию стоит лаунчер. VR, редакторы,
                # серверы и т.п. пропускаем.
                $launchType = [string]$l.type
                $isOption = $false
                if (-not [string]::IsNullOrEmpty($launchType) -and $launchType -ne 'default' -and $launchType -ne 'none') {
                    if ($launchType -match '^option\d*$') { $isOption = $true } else { continue }
                }
                $os = $null
                if ($l.config -ne $null) { $os = [string]$l.config.oslist }
                if (-not [string]::IsNullOrEmpty($os) -and $os -notmatch 'windows') { continue }
                $exe = ($exe -replace '/', '\').TrimStart('\')
                if ([System.IO.Path]::IsPathRooted($exe) -or $exe -match '(^|\\)\.\.(\\|$)') { continue }
                if ($isOption) {
                    if (-not $optionExes.Contains($exe)) { $optionExes.Add($exe) }
                } else {
                    if (-not $found.Contains($exe)) { $found.Add($exe) }
                }
            }
        }
        # Варианты выбора идут после основных записей.
        foreach ($o in $optionExes) { if (-not $found.Contains($o)) { $found.Add($o) } }
    } catch {}

    $global:steamLaunchExeCache[$appIdStr] = $found.ToArray()
    return @($found.ToArray())
}

# Ищет в папке игры файл, который Steam считает основным для этого App ID.
# Возвращает FileInfo или $null (если записи нет, сервис недоступен или такого
# файла в папке нет — тогда вызывающий код работает как раньше).
# Прямой запуск игры предпочтительнее лаунчера: сначала проверяются записи без
# слова "launcher" в пути, и только если ни одной из них нет в папке — лаунчеры.
# Сам лаунчер при этом остаётся в списке карточки для ручного выбора.
function Get-SteamHintedExecutable ($gamePath, $appId) {
    if ([string]::IsNullOrWhiteSpace($gamePath) -or -not (Test-Path -LiteralPath $gamePath)) { return $null }
    $rels = @(Get-SteamLaunchExecutables $appId)
    if ($rels.Count -eq 0) { return $null }

    $direct = @($rels | Where-Object { $_ -notmatch '(?i)launcher' })

    # БАГ-ФИКС: раньше при отсутствии прямого exe среди данных Steam функция
    # откатывалась на лаунчер из тех же данных ($launchers) и возвращала его
    # с ПОЛНОЙ уверенностью ("определён по данным Steam"), из-за чего вызывающий
    # код показывал зелёную галочку и даже автодобавлял игру в библиотеку без
    # диалога выбора. Проблема в том, что метаданные Steam для многих игр
    # (например, Baldur's Gate 3, App ID 1086940) вообще не объявляют прямой
    # exe как альтернативный вариант запуска — там прописан только сам
    # лаунчер (Launcher\LariLauncher.exe), хотя bin\bg3.exe прекрасно работает
    # и лежит в той же папке. В такой ситуации данные Steam не дают никакого
    # преимущества перед обычным локальным поиском exe (он и так найдёт
    # лаунчер как одного из кандидатов) — а вот ложная "уверенность" в выборе
    # именно лаунчера вместо прямого запуска игры была явной регрессией.
    # Поэтому теперь функция подтверждает выбор ТОЛЬКО если Steam указывает
    # прямой (не-лаунчер) exe; если такого нет — возвращаем null, и вызывающий
    # код переходит к обычному выбору (кэш/диалог), не выдавая лаунчер за
    # уверенно определённый файл запуска.
    foreach ($rel in @($direct)) {
        try {
            $full = Join-Path $gamePath $rel
            if (Test-Path -LiteralPath $full -PathType Leaf) { return (Get-Item -LiteralPath $full) }
        } catch {}
    }
    # Игра может лежать во вложенной папке (лишний уровень при копировании):
    # ищем файл с тем же хвостом пути, но только если совпадение ровно одно.
    foreach ($rel in @($direct)) {
        try {
            $leaf = [System.IO.Path]::GetFileName($rel)
            if ([string]::IsNullOrEmpty($leaf)) { continue }
            $suffix = '\' + $rel
            $nested = @(Get-ChildItem -LiteralPath $gamePath -Filter $leaf -File -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName.EndsWith($suffix, [System.StringComparison]::OrdinalIgnoreCase) })
            if ($nested.Count -eq 1) { return $nested[0] }
        } catch {}
    }
    return $null
}

# ===================== ПАРАМЕТРЫ ЗАПУСКА ИЗ STEAM (PICS: config.launch) =====================
# То же самое, что показывает SteamDB в разделе Configuration -> Launch Options
# (Executable / Arguments / Description для каждого варианта запуска) — но не
# HTML-страница steamdb.info (нестабильная разметка, может стоять защита от
# ботов), а тот же самый api.steamcmd.net, что уже используется чуть выше в
# Get-SteamLaunchExecutables — тот же исходный PICS-источник, просто без
# фильтрации по типу/ОС/лаунчеру: здесь нужны ВСЕ записи как есть, чтобы
# показать их пользователю на выбор в выпадающем списке карточки игры.
# Кэш и сетевой запрос сделаны отдельно от Get-SteamLaunchExecutables (не
# переиспользуют её кэш) — так изменения здесь не рискуют задеть уже рабочую
# автоподсказку exe.
$global:steamLaunchOptionsCache = @{}

# Небольшой локальный справочник самых распространённых аргументов командной
# строки (движки на Source/Source 2 и общие флаги самого Steam) — сама витрина
# Steam текстового объяснения по каждому отдельному флагу не даёт (только
# "Description" на весь вариант запуска целиком, и то не всегда), поэтому
# подсказку рядом с полем строим сами по известным флагам.
$global:knownLaunchArgHints = [ordered]@{
    '-vr'                  = 'запуск в режиме VR'
    '-novr'                = 'принудительно отключает VR-режим'
    '-console'             = 'открывает консоль разработчика при запуске'
    '-window'              = 'запуск в оконном режиме'
    '-windowed'            = 'запуск в оконном режиме'
    '-fullscreen'          = 'запуск в полноэкранном режиме'
    '-noborder'            = 'окно без рамки (borderless)'
    '-novid'               = 'пропускает вступительные видеоролики'
    '-nointro'             = 'пропускает вступительные видеоролики'
    '-high'                = 'запуск процесса с высоким приоритетом'
    '-low'                 = 'запуск процесса с низким приоритетом'
    '-nosound'             = 'отключает звук'
    '-safe'                = 'безопасный режим (минимальные настройки графики)'
    '-autoconfig'          = 'сбрасывает настройки видео/ввода к автоопределению'
    '-dx9'                 = 'принудительно DirectX 9'
    '-dx11'                = 'принудительно DirectX 11'
    '-dx12'                = 'принудительно DirectX 12'
    '-vulkan'              = 'принудительно рендерер Vulkan'
    '-gl'                  = 'принудительно рендерер OpenGL'
    '-opengl'              = 'принудительно рендерер OpenGL'
    '-particles'           = 'ограничивает количество частиц'
    '-heapsize'            = 'задаёт размер выделяемой памяти (в Кб, число после флага)'
    '-w'                   = 'ширина окна в пикселях (число после флага)'
    '-h'                   = 'высота окна в пикселях (число после флага)'
    '-freq'                = 'частота обновления экрана, Гц (число после флага)'
    '-refresh'             = 'частота обновления экрана, Гц (число после флага)'
    '-steam'               = 'запуск через клиент Steam (достижения/оверлей)'
    '-retail'              = 'сборка розничной версии (не отладочная)'
    '-noasserts'           = 'отключает внутренние проверки (assert) движка'
    '-nopassiveasserts'    = 'отключает пассивные проверки (assert) движка'
    '-insecure'            = 'запуск без Valve Anti-Cheat'
    '-dedicated'           = 'запуск в режиме выделенного сервера'
    '-nojoy'               = 'отключает поддержку геймпада/джойстика'
    '-nohltv'              = 'отключает поддержку SourceTV'
    '-tools'               = 'запуск в режиме инструментов разработчика'
    '-allowdebug'          = 'разрешает отладочный режим'
    '+map'                 = 'сразу загружает указанную карту (имя карты после флага)'
    '+connect'             = 'сразу подключается к серверу (адрес после флага)'
    '+exec'                = 'выполняет указанный конфиг-файл при запуске'
}

# Английские описания тех же флагов (используются при language=en).
$global:knownLaunchArgHintsEn = [ordered]@{
    '-vr'                  = 'launch in VR mode'
    '-novr'                = 'force-disable VR mode'
    '-console'             = 'open the developer console on launch'
    '-window'              = 'launch in windowed mode'
    '-windowed'            = 'launch in windowed mode'
    '-fullscreen'          = 'launch in fullscreen mode'
    '-noborder'            = 'borderless window'
    '-novid'               = 'skip the intro videos'
    '-nointro'             = 'skip the intro videos'
    '-high'                = 'run the process with high priority'
    '-low'                 = 'run the process with low priority'
    '-nosound'             = 'disable sound'
    '-safe'                = 'safe mode (minimal graphics settings)'
    '-autoconfig'          = 'reset video/input settings to auto-detect'
    '-dx9'                 = 'force DirectX 9'
    '-dx11'                = 'force DirectX 11'
    '-dx12'                = 'force DirectX 12'
    '-vulkan'              = 'force the Vulkan renderer'
    '-gl'                  = 'force the OpenGL renderer'
    '-opengl'              = 'force the OpenGL renderer'
    '-particles'           = 'limit the number of particles'
    '-heapsize'            = 'set the allocated memory size (in KB, number after the flag)'
    '-w'                   = 'window width in pixels (number after the flag)'
    '-h'                   = 'window height in pixels (number after the flag)'
    '-freq'                = 'screen refresh rate, Hz (number after the flag)'
    '-refresh'             = 'screen refresh rate, Hz (number after the flag)'
    '-steam'               = 'launch via the Steam client (achievements/overlay)'
    '-retail'              = 'retail build (not debug)'
    '-noasserts'           = 'disable the engine''s internal assert checks'
    '-nopassiveasserts'    = 'disable the engine''s passive assert checks'
    '-insecure'            = 'launch without Valve Anti-Cheat'
    '-dedicated'           = 'launch in dedicated server mode'
    '-nojoy'               = 'disable gamepad/joystick support'
    '-nohltv'              = 'disable SourceTV support'
    '-tools'               = 'launch in developer tools mode'
    '-allowdebug'          = 'allow debug mode'
    '+map'                 = 'load the specified map immediately (map name after the flag)'
    '+connect'             = 'connect to a server immediately (address after the flag)'
    '+exec'                = 'execute the specified config file on launch'
}

# Китайские описания тех же флагов (используются при language=zh).
$global:knownLaunchArgHintsZh = [ordered]@{
    '-vr'                  = '以 VR 模式启动'
    '-novr'                = '强制禁用 VR 模式'
    '-console'             = '启动时打开开发者控制台'
    '-window'              = '以窗口模式启动'
    '-windowed'            = '以窗口模式启动'
    '-fullscreen'          = '以全屏模式启动'
    '-noborder'            = '无边框窗口'
    '-novid'               = '跳过开场视频'
    '-nointro'             = '跳过开场视频'
    '-high'                = '以高优先级运行进程'
    '-low'                 = '以低优先级运行进程'
    '-nosound'             = '禁用声音'
    '-safe'                = '安全模式（最低图形设置）'
    '-autoconfig'          = '将视频/输入设置重置为自动检测'
    '-dx9'                 = '强制使用 DirectX 9'
    '-dx11'                = '强制使用 DirectX 11'
    '-dx12'                = '强制使用 DirectX 12'
    '-vulkan'              = '强制使用 Vulkan 渲染器'
    '-gl'                  = '强制使用 OpenGL 渲染器'
    '-opengl'              = '强制使用 OpenGL 渲染器'
    '-particles'           = '限制粒子数量'
    '-heapsize'            = '设置分配的内存大小（单位 KB，数值跟在参数后）'
    '-w'                   = '窗口宽度，单位像素（数值跟在参数后）'
    '-h'                   = '窗口高度，单位像素（数值跟在参数后）'
    '-freq'                = '屏幕刷新率，单位 Hz（数值跟在参数后）'
    '-refresh'             = '屏幕刷新率，单位 Hz（数值跟在参数后）'
    '-steam'               = '通过 Steam 客户端启动（成就/覆盖界面）'
    '-retail'              = '零售版本（非调试版）'
    '-noasserts'           = '禁用引擎内部的断言（assert）检查'
    '-nopassiveasserts'    = '禁用引擎的被动断言（assert）检查'
    '-insecure'            = '不启用 Valve 反作弊（VAC）启动'
    '-dedicated'           = '以专用服务器模式启动'
    '-nojoy'               = '禁用手柄/摇杆支持'
    '-nohltv'              = '禁用 SourceTV 支持'
    '-tools'               = '以开发者工具模式启动'
    '-allowdebug'          = '允许调试模式'
    '+map'                 = '立即加载指定地图（地图名跟在参数后）'
    '+connect'             = '立即连接到服务器（地址跟在参数后）'
    '+exec'                = '启动时执行指定的配置文件'
}

# Испанские описания тех же флагов (используются при language=es).
$global:knownLaunchArgHintsEs = [ordered]@{
    '-vr'                  = 'iniciar en modo VR'
    '-novr'                = 'desactivar a la fuerza el modo VR'
    '-console'             = 'abrir la consola de desarrollador al iniciar'
    '-window'              = 'iniciar en modo ventana'
    '-windowed'            = 'iniciar en modo ventana'
    '-fullscreen'          = 'iniciar en pantalla completa'
    '-noborder'            = 'ventana sin bordes'
    '-novid'               = 'omitir los vídeos de introducción'
    '-nointro'             = 'omitir los vídeos de introducción'
    '-high'                = 'ejecutar el proceso con prioridad alta'
    '-low'                 = 'ejecutar el proceso con prioridad baja'
    '-nosound'             = 'desactivar el sonido'
    '-safe'                = 'modo seguro (ajustes gráficos mínimos)'
    '-autoconfig'          = 'restablecer los ajustes de vídeo/entrada a la detección automática'
    '-dx9'                 = 'forzar DirectX 9'
    '-dx11'                = 'forzar DirectX 11'
    '-dx12'                = 'forzar DirectX 12'
    '-vulkan'              = 'forzar el renderizador Vulkan'
    '-gl'                  = 'forzar el renderizador OpenGL'
    '-opengl'              = 'forzar el renderizador OpenGL'
    '-particles'           = 'limitar el número de partículas'
    '-heapsize'            = 'establecer el tamaño de memoria asignada (en KB, número tras el parámetro)'
    '-w'                   = 'ancho de la ventana en píxeles (número tras el parámetro)'
    '-h'                   = 'alto de la ventana en píxeles (número tras el parámetro)'
    '-freq'                = 'frecuencia de actualización de pantalla, Hz (número tras el parámetro)'
    '-refresh'             = 'frecuencia de actualización de pantalla, Hz (número tras el parámetro)'
    '-steam'               = 'iniciar mediante el cliente de Steam (logros/overlay)'
    '-retail'              = 'compilación comercial (no de depuración)'
    '-noasserts'           = 'desactivar las comprobaciones internas (assert) del motor'
    '-nopassiveasserts'    = 'desactivar las comprobaciones pasivas (assert) del motor'
    '-insecure'            = 'iniciar sin Valve Anti-Cheat'
    '-dedicated'           = 'iniciar en modo servidor dedicado'
    '-nojoy'               = 'desactivar el soporte de mando/joystick'
    '-nohltv'              = 'desactivar el soporte de SourceTV'
    '-tools'               = 'iniciar en modo de herramientas de desarrollo'
    '-allowdebug'          = 'permitir el modo de depuración'
    '+map'                 = 'cargar de inmediato el mapa indicado (nombre del mapa tras el parámetro)'
    '+connect'             = 'conectarse de inmediato a un servidor (dirección tras el parámetro)'
    '+exec'                = 'ejecutar el archivo de configuración indicado al iniciar'
}

# Португальские (бразильские) описания тех же флагов (используются при language=pt).
$global:knownLaunchArgHintsPt = [ordered]@{
    '-vr'                  = 'iniciar no modo VR'
    '-novr'                = 'forçar a desativação do modo VR'
    '-console'             = 'abrir o console do desenvolvedor ao iniciar'
    '-window'              = 'iniciar em modo janela'
    '-windowed'            = 'iniciar em modo janela'
    '-fullscreen'          = 'iniciar em tela cheia'
    '-noborder'            = 'janela sem bordas'
    '-novid'               = 'pular os vídeos de introdução'
    '-nointro'             = 'pular os vídeos de introdução'
    '-high'                = 'executar o processo com prioridade alta'
    '-low'                 = 'executar o processo com prioridade baixa'
    '-nosound'             = 'desativar o som'
    '-safe'                = 'modo seguro (configurações gráficas mínimas)'
    '-autoconfig'          = 'redefinir as configurações de vídeo/entrada para a detecção automática'
    '-dx9'                 = 'forçar o DirectX 9'
    '-dx11'                = 'forçar o DirectX 11'
    '-dx12'                = 'forçar o DirectX 12'
    '-vulkan'              = 'forçar o renderizador Vulkan'
    '-gl'                  = 'forçar o renderizador OpenGL'
    '-opengl'              = 'forçar o renderizador OpenGL'
    '-particles'           = 'limitar o número de partículas'
    '-heapsize'            = 'definir o tamanho da memória alocada (em KB, número após o parâmetro)'
    '-w'                   = 'largura da janela em pixels (número após o parâmetro)'
    '-h'                   = 'altura da janela em pixels (número após o parâmetro)'
    '-freq'                = 'taxa de atualização da tela, Hz (número após o parâmetro)'
    '-refresh'             = 'taxa de atualização da tela, Hz (número após o parâmetro)'
    '-steam'               = 'iniciar pelo cliente da Steam (conquistas/overlay)'
    '-retail'              = 'versão comercial (não de depuração)'
    '-noasserts'           = 'desativar as verificações internas (assert) do motor'
    '-nopassiveasserts'    = 'desativar as verificações passivas (assert) do motor'
    '-insecure'            = 'iniciar sem o Valve Anti-Cheat'
    '-dedicated'           = 'iniciar no modo de servidor dedicado'
    '-nojoy'               = 'desativar o suporte a controle/joystick'
    '-nohltv'              = 'desativar o suporte ao SourceTV'
    '-tools'               = 'iniciar no modo de ferramentas de desenvolvimento'
    '-allowdebug'          = 'permitir o modo de depuração'
    '+map'                 = 'carregar imediatamente o mapa indicado (nome do mapa após o parâmetro)'
    '+connect'             = 'conectar imediatamente a um servidor (endereço após o parâmetro)'
    '+exec'                = 'executar o arquivo de configuração indicado ao iniciar'
}

# Немецкие описания тех же флагов (используются при language=de).
$global:knownLaunchArgHintsDe = [ordered]@{
    '-vr'                  = 'im VR-Modus starten'
    '-novr'                = 'VR-Modus erzwungen deaktivieren'
    '-console'             = 'beim Start die Entwicklerkonsole öffnen'
    '-window'              = 'im Fenstermodus starten'
    '-windowed'            = 'im Fenstermodus starten'
    '-fullscreen'          = 'im Vollbildmodus starten'
    '-noborder'            = 'randloses Fenster'
    '-novid'               = 'Intro-Videos überspringen'
    '-nointro'             = 'Intro-Videos überspringen'
    '-high'                = 'Prozess mit hoher Priorität ausführen'
    '-low'                 = 'Prozess mit niedriger Priorität ausführen'
    '-nosound'             = 'Ton deaktivieren'
    '-safe'                = 'abgesicherter Modus (minimale Grafikeinstellungen)'
    '-autoconfig'          = 'Video-/Eingabeeinstellungen auf automatische Erkennung zurücksetzen'
    '-dx9'                 = 'DirectX 9 erzwingen'
    '-dx11'                = 'DirectX 11 erzwingen'
    '-dx12'                = 'DirectX 12 erzwingen'
    '-vulkan'              = 'Vulkan-Renderer erzwingen'
    '-gl'                  = 'OpenGL-Renderer erzwingen'
    '-opengl'              = 'OpenGL-Renderer erzwingen'
    '-particles'           = 'Anzahl der Partikel begrenzen'
    '-heapsize'            = 'Größe des zugewiesenen Speichers festlegen (in KB, Zahl nach dem Parameter)'
    '-w'                   = 'Fensterbreite in Pixeln (Zahl nach dem Parameter)'
    '-h'                   = 'Fensterhöhe in Pixeln (Zahl nach dem Parameter)'
    '-freq'                = 'Bildwiederholrate in Hz (Zahl nach dem Parameter)'
    '-refresh'             = 'Bildwiederholrate in Hz (Zahl nach dem Parameter)'
    '-steam'               = 'über den Steam-Client starten (Erfolge/Overlay)'
    '-retail'              = 'Retail-Build (kein Debug)'
    '-noasserts'           = 'interne Assert-Prüfungen der Engine deaktivieren'
    '-nopassiveasserts'    = 'passive Assert-Prüfungen der Engine deaktivieren'
    '-insecure'            = 'ohne Valve Anti-Cheat starten'
    '-dedicated'           = 'im Modus für dedizierte Server starten'
    '-nojoy'               = 'Gamepad-/Joystick-Unterstützung deaktivieren'
    '-nohltv'              = 'SourceTV-Unterstützung deaktivieren'
    '-tools'               = 'im Entwicklerwerkzeug-Modus starten'
    '-allowdebug'          = 'Debug-Modus erlauben'
    '+map'                 = 'die angegebene Karte sofort laden (Kartenname nach dem Parameter)'
    '+connect'             = 'sofort mit einem Server verbinden (Adresse nach dem Parameter)'
    '+exec'                = 'die angegebene Konfigurationsdatei beim Start ausführen'
}

# Возвращает массив [PSCustomObject]@{ Index; Executable; Arguments; Type;
# Description; OS } — все варианты запуска, которые Steam знает для App ID,
# либо пустой массив (если запись отсутствует или сервис не ответил).
# Результат кэшируется на сеанс по App ID.
function Get-SteamDbLaunchOptions ($appId) {
    $appIdStr = [string]$appId
    if ($appIdStr -notmatch '^\d+$') { return @() }
    if ($global:steamLaunchOptionsCache.ContainsKey($appIdStr)) { return @($global:steamLaunchOptionsCache[$appIdStr]) }

    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
    $url = "https://api.steamcmd.net/v1/info/$appIdStr"
    $data = Invoke-BackgroundJsonRequest {
        param($u)
        try {
            return (Invoke-RestMethod -Uri $u -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -TimeoutSec 10 -ErrorAction Stop)
        } catch {
            try {
                $rawLines = curl.exe -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" --connect-timeout 6 --max-time 10 $u
                $rawJson = ($rawLines -join "")
                if (-not [string]::IsNullOrWhiteSpace($rawJson)) { return ($rawJson | ConvertFrom-Json -ErrorAction Stop) }
            } catch {}
            return $null
        }
    } @($url) 20

    $result = New-Object System.Collections.Generic.List[object]
    if ($data -ne $null) {
        try {
            $appNode = $null
            if ($data.data -ne $null) {
                $appNode = $data.data.PSObject.Properties | Where-Object { $_.Name -eq $appIdStr } | Select-Object -First 1
            }
            $launch = $null
            if ($appNode -ne $null -and $appNode.Value -ne $null -and $appNode.Value.config -ne $null) { $launch = $appNode.Value.config.launch }
            if ($launch -ne $null) {
                $launchItems = @()
                if ($launch -is [System.Array]) {
                    $launchItems = @($launch)
                } else {
                    $launchItems = @($launch.PSObject.Properties |
                        Sort-Object { $n = 0; if ([int]::TryParse($_.Name, [ref]$n)) { $n } else { [int]::MaxValue } } |
                        ForEach-Object { $_.Value })
                }
                $idx = 0
                foreach ($l in $launchItems) {
                    if ($l -eq $null) { continue }
                    $exe = [string]$l.executable
                    if ([string]::IsNullOrWhiteSpace($exe)) { continue }
                    $osList = $null
                    if ($l.config -ne $null) { $osList = [string]$l.config.oslist }
                    $entry = [PSCustomObject]@{
                        Index       = $idx
                        Executable  = ($exe -replace '/', '\')
                        Arguments   = [string]$l.arguments
                        Type        = [string]$l.type
                        Description = [string]$l.description
                        OS          = if ([string]::IsNullOrWhiteSpace($osList)) { 'windows' } else { $osList }
                    }
                    $result.Add($entry)
                    $idx++
                }
            }
        } catch {}
    }

    $arr = $result.ToArray()
    $global:steamLaunchOptionsCache[$appIdStr] = $arr
    return @($arr)
}

# Короткая подсказка "что делает" выбранный вариант запуска — своё описание
# из Steam (если есть) плюс расшифровка узнаваемых флагов из Arguments.
function Format-LaunchOptionHint ($entry) {
    if ($entry -eq $null) { return '' }
    $parts = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace([string]$entry.Description)) { [void]$parts.Add([string]$entry.Description) }
    if (-not [string]::IsNullOrWhiteSpace([string]$entry.Arguments)) {
        $flagHints = New-Object System.Collections.Generic.List[string]
        $tokens = [System.Text.RegularExpressions.Regex]::Split([string]$entry.Arguments, '\s+') | Where-Object { $_ -match '^[+-]' }
        foreach ($tok in $tokens) {
            $hintTable = switch ([string]$global:language) { 'en' { $global:knownLaunchArgHintsEn } 'zh' { $global:knownLaunchArgHintsZh } 'es' { $global:knownLaunchArgHintsEs } 'pt' { $global:knownLaunchArgHintsPt } 'de' { $global:knownLaunchArgHintsDe } default { $global:knownLaunchArgHints } }
            if ($hintTable.Contains($tok)) { [void]$flagHints.Add("$tok — " + $hintTable[$tok]) }
        }
        if ($flagHints.Count -gt 0) { [void]$parts.Add(($flagHints -join '; ')) }
    }
    if ($parts.Count -eq 0) { return (T 'lo_no_hint') }
    return ($parts -join ' · ')
}

function Save-FirstWorkingUrl ($urls, $destPath) {
    if ($urls -eq $null) { return $false }
    foreach ($candidateUrl in @($urls)) {
        if ([string]::IsNullOrEmpty([string]$candidateUrl)) { continue }
        if (Download-RemoteImage ([string]$candidateUrl) $destPath) { return $true }
    }
    return $false
}

# Пока в карточке игры крутится анимация загрузки, UI-поток не должен намертво
# блокироваться на скачивании: Invoke-WebRequest и "& curl.exe" держат поток до
# конца запроса, перерисовать спиннер в это время некому — он просто застывает.
# Поэтому на время работы карточки поднимается флаг $global:uiPumpDuringDownload:
# тогда файл качает отдельный процесс curl.exe, а мы ждём его, прокачивая очередь
# сообщений WinForms. Никаких обращений к контролам из фонового потока по-прежнему
# нет — всё происходит в UI-потоке, просто он не заблокирован.
$global:uiPumpDuringDownload = $false

# ===================== ФОНОВЫЕ (НЕБЛОКИРУЮЩИЕ) JSON-ЗАПРОСЫ =====================
# В отличие от Invoke-UiPumpingDownload (отдельный ПРОЦЕСС curl.exe — подходит
# для скачивания файлов), здесь сетевой вызов выполняется в отдельном
# PowerShell-runspace — это настоящий .NET-поток внутри того же процесса, а не
# внешний процесс. UI-поток при этом свободен и прокачивает очередь сообщений
# (спиннер продолжает крутиться), пока фоновый поток ждёт ответ сервера.
#
# ВАЖНО: это НЕ то же самое, что уже пробовали и откатили в Load-EditorSgdbPreviews
# (см. FIX 8) — там для JSON/autocomplete пытались использовать отдельный
# curl.exe-ПРОЦЕСС на каждый запрос, и именно это вызывало зависания на этапе
# "ищу…". Здесь никаких внешних процессов не создаётся вообще — только
# встроенный runspace, поэтому того риска нет.
#
# Ограничение: scriptblock выполняется в СВОЁМ пустом runspace — у него нет
# доступа к функциям и $global:-переменным основного скрипта. Ему можно
# передать только простые данные через $argumentList (строки, числа, hashtable
# заголовков) и использовать только встроенные команды (Invoke-RestMethod,
# ConvertFrom-Json, curl.exe и т.п.).
function Invoke-BackgroundJsonRequest ($scriptBlock, [object[]]$argumentList, [int]$maxSeconds = 20) {
    $ps = $null
    $async = $null
    try {
        $ps = [System.Management.Automation.PowerShell]::Create()
        [void]$ps.AddScript($scriptBlock)
        if ($argumentList) { foreach ($a in $argumentList) { [void]$ps.AddArgument($a) } }
        $async = $ps.BeginInvoke()
    } catch {
        # Не удалось поднять фоновый runspace (крайне редкий случай) —
        # выполняем как раньше, блокирующим способом, лишь бы не потерять результат.
        try { if ($ps) { $ps.Dispose() } } catch {}
        try { return (& $scriptBlock @argumentList) } catch { return $null }
    }

    $deadline = (Get-Date).AddSeconds([Math]::Max(1, $maxSeconds))
    try {
        while (-not $async.IsCompleted) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 30
            if ((Get-Date) -gt $deadline) { try { $ps.Stop() } catch {}; break }
        }
        $result = $null
        try { $result = $ps.EndInvoke($async) } catch { $result = $null }
        if ($result -eq $null) { return $null }
        $items = @($result)
        if ($items.Count -eq 0) { return $null }
        if ($items.Count -eq 1) { return $items[0] }
        return $items
    } finally {
        try { $ps.Dispose() } catch {}
    }
}

# ===================== ОБЩАЯ ОБЁРТКА ДЛЯ ЗАПРОСОВ К SteamGridDB =====================
# Нужна, чтобы в ОДНОМ месте отличать HTTP 401 (ключ невалиден/отозван — имеет
# смысл сбросить его и попробовать переполучить ещё раз) от обычного сетевого
# сбоя (таймаут, DNS, 5xx и т.п. — повторять с тем же ключом бессмысленно).
# Раньше эта развилка была вручную продублирована в паре мест (например,
# автодополнение поиска по названию), а в паре других мест (получение
# ассетов по Steam App ID и по SGDB Game ID) её не было вовсе — там любая
# ошибка, включая 401 из-за протухшего ключа, тихо проглатывалась пустым
# catch {}, и пользователь просто видел "обложки не найдены" без единого
# шанса, что ключ переполучится и следующий же запрос в этой карточке уже
# отработает.
#
# Возвращает [PSCustomObject]@{ Success; Data; WasUnauthorized; ErrorMessage }
#   Success         — $true, если запрос (возможно, уже после повторной
#                      попытки с новым ключом) вернул success:true и данные.
#   Data            — тело поля .data ответа SGDB, либо $null.
#   WasUnauthorized — $true, если сервер хоть раз ответил 401 — вызывающий
#                      код может опираться на этот флаг, а не парсить текст
#                      исключения самостоятельно.
#   ErrorMessage    — текст последней ошибки, если Success -eq $false.
function Invoke-SgdbApiRequest ($url, [hashtable]$headers, [int]$timeoutSec = 20, [switch]$NoKeyRetry) {
    $wasUnauthorized = $false
    $errMsg = $null
    $resp = $null

    try {
        $resp = Invoke-RestMethod -Uri $url -Headers $headers -TimeoutSec $timeoutSec -ErrorAction Stop
    } catch {
        $errMsg = [string]$_.Exception.Message
        $is401 = $false
        try { $is401 = ($_.Exception.Response -ne $null -and $_.Exception.Response.StatusCode.value__ -eq 401) } catch {}

        if ($is401) {
            $wasUnauthorized = $true
            if (-not $NoKeyRetry) {
                # Ключ, скорее всего, отозван/истёк — сбрасываем и переполучаем,
                # затем даём ОДНУ повторную попытку с новым ключом.
                $global:steamGridDbApiKey = ""
                $global:steamGridDbApiKeyValid = $false
                $newKey = [string](Ensure-SteamGridDbApiKey)
                if (-not [string]::IsNullOrWhiteSpace($newKey)) {
                    $headers = @{ Authorization = "Bearer $newKey" }
                    try {
                        $resp = Invoke-RestMethod -Uri $url -Headers $headers -TimeoutSec $timeoutSec -ErrorAction Stop
                        $errMsg = $null
                    } catch {
                        $errMsg = [string]$_.Exception.Message
                    }
                }
            }
        }
    }

    $ok = ($resp -ne $null -and $resp.success -eq $true -and $resp.data -ne $null)
    return [PSCustomObject]@{
        Success         = $ok
        Data            = if ($ok) { $resp.data } else { $null }
        WasUnauthorized = $wasUnauthorized
        ErrorMessage    = $errMsg
    }
}

function Invoke-UiPumpingDownload ($url, $targetPath, [int]$maxSeconds = 40) {
    # $true  — файл скачан
    # $false — не скачался
    # $null  — не удалось даже запустить curl.exe; вызывающий код должен
    #          пойти обычным (блокирующим) путём.
    $proc = $null
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'curl.exe'
        $psi.Arguments = '-L -s -S -f --connect-timeout 10 --max-time {0} -A "Mozilla/5.0" -o "{1}" "{2}"' -f $maxSeconds, $targetPath, $url
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        if (-not $proc.Start()) { return $null }
    } catch { return $null }

    $exitCode = 1
    try {
        $deadline = (Get-Date).AddSeconds([Math]::Max(5, $maxSeconds) + 10)
        while (-not $proc.HasExited) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 40
            if ((Get-Date) -gt $deadline) { try { $proc.Kill() } catch {}; break }
        }
        try { $proc.WaitForExit(2000) | Out-Null } catch {}
        try { $exitCode = [int]$proc.ExitCode } catch { $exitCode = 1 }
    } catch { $exitCode = 1 }
    finally { try { $proc.Dispose() } catch {} }

    if ($exitCode -eq 0 -and (Test-Path $targetPath) -and (Get-Item $targetPath -ErrorAction SilentlyContinue).Length -ge 512) { return $true }
    Remove-Item $targetPath -Force -ErrorAction SilentlyContinue
    return $false
}

function Download-RemoteImage ($url, $targetPath) {
    if ([string]::IsNullOrWhiteSpace([string]$url)) { return $false }
    try {
        $parent = Split-Path -Parent $targetPath
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    } catch {}

    # Карточка игры: качаем так, чтобы анимация загрузки продолжала крутиться.
    if ($global:uiPumpDuringDownload) {
        $pumped = Invoke-UiPumpingDownload $url $targetPath 40
        if ($pumped -eq $true) { return $true }
        if ($pumped -eq $false) { return $false }
        # $null — curl.exe недоступен, идём обычным путём ниже.
    }

    try {
        Invoke-WebRequest -Uri $url -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -TimeoutSec 30 -UseBasicParsing -OutFile $targetPath -ErrorAction Stop
        if ((Test-Path $targetPath) -and (Get-Item $targetPath).Length -ge 512) { return $true }
    } catch {}
    Remove-Item $targetPath -Force -ErrorAction SilentlyContinue
    try {
        & curl.exe -L -s -S -f --connect-timeout 10 --max-time 40 -A "Mozilla/5.0" $url -o $targetPath 2>$null
        if ($LASTEXITCODE -eq 0 -and (Test-Path $targetPath) -and (Get-Item $targetPath).Length -ge 512) { return $true }
    } catch {}
    Remove-Item $targetPath -Force -ErrorAction SilentlyContinue
    return $false
}

function Get-SteamGridDbAssetsBySteamAppId ($steamAppId) {
    if ([string]::IsNullOrWhiteSpace([string]$global:steamGridDbApiKey)) { return $null }
    $headers = @{ Authorization = "Bearer $($global:steamGridDbApiKey)" }
    $result = [ordered]@{ Grids = @(); Heroes = @(); Logos = @() }
    foreach ($kind in @('grids','heroes','logos')) {
        $url = "https://www.steamgriddb.com/api/v2/$kind/steam/$steamAppId"
        $r = Invoke-SgdbApiRequest $url $headers 30
        if ($r.Success) {
            $prop = $kind.Substring(0,1).ToUpper() + $kind.Substring(1)
            $result[$prop] = @($r.Data)
        }
    }
    $total = @($result.Grids).Count + @($result.Heroes).Count + @($result.Logos).Count
    if ($total -eq 0) { return $null }
    return [PSCustomObject]$result
}

function Try-FillMissingLogoFromSteamGridDB ($steamAppId) {
    if (Test-Path (Join-Path $global:tempCovers 'temp_logo.png')) { return $true }
    if ([string]::IsNullOrWhiteSpace([string]$global:steamGridDbApiKey)) { return $false }
    $assets = Get-SteamGridDbAssetsBySteamAppId $steamAppId
    if ($assets -eq $null -or @($assets.Logos).Count -eq 0) { return $false }
    foreach ($logo in @($assets.Logos)) {
        if (Download-RemoteImage ([string]$logo.url) (Join-Path $global:tempCovers 'temp_logo.png')) { return $true }
    }
    return $false
}

function Download-CoversToTemp ($cleanAppID, [bool]$allowSgdbLogo = $true) {
    # БАГ-ФИКС: без очистки temp-папки перед каждым скачиванием при пакетном
    # добавлении нескольких игр подряд файл, не найденный (404) для ТЕКУЩЕЙ
    # игры, мог остаться от ПРЕДЫДУЩЕЙ игры (curl.exe с -o не удаляет старый
    # файл, если новый запрос не удался) — и в грид попадала чужая картинка.
    if (Test-Path $global:tempCovers) { Remove-Item $global:tempCovers -Recurse -Force -ErrorAction SilentlyContinue }
    if (-not (Test-Path $global:tempCovers)) { New-Item -ItemType Directory -Path $global:tempCovers | Out-Null }
    $hexApps = "68747470733a2f2f7368617265642e616b616d61692e737465616d7374617469632e636f6d2f73746f72655f6974656d5f6173736574732f737465616d2f617070732f"
    $bytesApps = New-Object byte[] ($hexApps.Length / 2)
    for ($i = 0; $i -lt $hexApps.Length; $i += 2) { $bytesApps[$i/2] = [Convert]::ToByte($hexApps.Substring($i, 2), 16) }
    $baseApps = [System.Text.Encoding]::ASCII.GetString($bytesApps)
    
    # БАГ-ФИКС: без флага -f curl.exe при ответе 404 от CDN (у некоторых
    # изданий/бандлов нет всех четырёх картинок) всё равно СОЗДАВАЛ файл
    # по пути -o (с телом ошибки или пустой) — Test-Path в местах применения
    # считал такой файл существующим, и в итоге в grid Steam попадала
    # битая/пустая "обложка" вместо того, чтобы честно пропустить
    # отсутствующий ассет. Теперь curl с -f не пишет файл при HTTP-ошибке,
    # а на всякий случай (некоторые сборки curl всё равно оставляют пустой
    # файл) дополнительно чистим файлы подозрительно малого размера.

    # ЛОКАЛИЗАЦИЯ: если в «Настройках» выбран не английский язык, СНАЧАЛА берём
    # обложки/логотип на этом языке из PICS (library_assets_full хранит файлы
    # по языкам). Прямые ссылки ниже всегда отдают стандартную (английскую)
    # версию, поэтому они используются только для того, чего ещё не хватает.
    # Если у игры нет локализованных ассетов — PICS сам отдаёт английские.
    $steamLang = Get-SteamAssetLanguage
    $pics = $null
    # Язык, на котором в итоге загрузились обложки (показывает кнопка региона в карточке).
    $script:lastCoversLanguage = 'english'
    if ($steamLang -ne 'english') {
        $pics = Get-SteamPicsAssetUrls $cleanAppID $steamLang
        if ($pics -ne $null) {
            Save-FirstWorkingUrl $pics.Capsule (Join-Path $global:tempCovers "temp_p.jpg")      | Out-Null
            Save-FirstWorkingUrl $pics.Hero    (Join-Path $global:tempCovers "temp_hero.jpg")   | Out-Null
            Save-FirstWorkingUrl $pics.Header  (Join-Path $global:tempCovers "temp_header.jpg") | Out-Null
            Save-FirstWorkingUrl $pics.Logo    (Join-Path $global:tempCovers "temp_logo.png")   | Out-Null
            foreach ($picsFile in @("temp_p.jpg", "temp_hero.jpg", "temp_header.jpg", "temp_logo.png")) {
                if (Test-Path (Join-Path $global:tempCovers $picsFile)) { $script:lastCoversLanguage = [string]$pics.Language; break }
            }
        }
    }

    if (-not (Test-Path (Join-Path $global:tempCovers "temp_p.jpg")))      { Download-RemoteImage "${baseApps}${cleanAppID}/library_600x900.jpg" (Join-Path $global:tempCovers "temp_p.jpg") | Out-Null }
    if (-not (Test-Path (Join-Path $global:tempCovers "temp_hero.jpg")))   { Download-RemoteImage "${baseApps}${cleanAppID}/library_hero.jpg" (Join-Path $global:tempCovers "temp_hero.jpg") | Out-Null }
    if (-not (Test-Path (Join-Path $global:tempCovers "temp_logo.png")))   { Download-RemoteImage "${baseApps}${cleanAppID}/logo.png" (Join-Path $global:tempCovers "temp_logo.png") | Out-Null }
    if (-not (Test-Path (Join-Path $global:tempCovers "temp_header.jpg"))) { Download-RemoteImage "${baseApps}${cleanAppID}/header.jpg" (Join-Path $global:tempCovers "temp_header.jpg") | Out-Null }

    foreach ($tempFile in @("temp_p.jpg", "temp_hero.jpg", "temp_logo.png", "temp_header.jpg")) {
        $tempFilePath = Join-Path $global:tempCovers $tempFile
        if ((Test-Path $tempFilePath) -and (Get-Item $tempFilePath).Length -lt 512) {
            Remove-Item $tempFilePath -Force -ErrorAction SilentlyContinue
        }
    }

    # БАГ-ФИКС: прямое угадывание ссылки по фиксированному шаблону выше не
    # находит обложку для игр с CDN-путём на хеш-префиксе (см. комментарий
    # у Get-SteamAssetUrlsViaApi) — раньше это приводило к ложному "обложка
    # не найдена"/"только фон без обложки", хотя обложка у игры реально
    # есть.
    #
    # БАГ-ФИКС: раньше API-фолбэк запускался, только если ОБА — и капсула,
    # и header — не скачались напрямую. Из-за этого, если капсула успешно
    # скачивалась по старому пути, а вот логотип (у него своя, отдельная
    # хеш-часть в пути) — нет, логотип так и оставался недокачанным: до
    # него просто не доходило дело. Теперь каждая из четырёх картинок
    # проверяется НЕЗАВИСИМО, и если не хватает хотя бы одной — запрашиваем
    # точные ссылки через официальный API и докачиваем именно то, чего
    # не хватает (остальные, уже скачанные напрямую, не трогаем).
    $missingCapsule = -not (Test-Path (Join-Path $global:tempCovers "temp_p.jpg"))
    $missingHero    = -not (Test-Path (Join-Path $global:tempCovers "temp_hero.jpg"))
    $missingHeader  = -not (Test-Path (Join-Path $global:tempCovers "temp_header.jpg"))
    $missingLogo    = -not (Test-Path (Join-Path $global:tempCovers "temp_logo.png"))
    if ($missingCapsule -or $missingHero -or $missingHeader -or $missingLogo) {
        $resolved = Get-SteamAssetUrlsViaApi $cleanAppID $steamLang
        if ($resolved -ne $null) {
            if ($missingCapsule) { Save-FirstWorkingUrl $resolved.Capsule (Join-Path $global:tempCovers "temp_p.jpg") | Out-Null }
            if ($missingHero)    { Save-FirstWorkingUrl $resolved.Hero    (Join-Path $global:tempCovers "temp_hero.jpg") | Out-Null }
            if ($missingHeader)  { Save-FirstWorkingUrl $resolved.Header  (Join-Path $global:tempCovers "temp_header.jpg") | Out-Null }
            if ($missingLogo)    { Save-FirstWorkingUrl $resolved.Logo    (Join-Path $global:tempCovers "temp_logo.png") | Out-Null }
            foreach ($tempFile in @("temp_p.jpg", "temp_hero.jpg", "temp_logo.png", "temp_header.jpg")) {
                $tempFilePath = Join-Path $global:tempCovers $tempFile
                if ((Test-Path $tempFilePath) -and (Get-Item $tempFilePath).Length -lt 512) {
                    Remove-Item $tempFilePath -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    # БАГ-ФИКС: последний рубеж для ОФИЦИАЛЬНЫХ ресурсов Steam — PICS.
    # Сюда почти всегда попадает логотип (в GetItems его нет вовсе, а прямой
    # путь без хеш-префикса у новых игр отдаёт 404). Капсулу/hero/header тоже
    # пробуем добрать здесь, если предыдущие шаги их не нашли. Только после
    # этого имеет смысл уходить в SteamGridDB.
    $missingCapsule = -not (Test-Path (Join-Path $global:tempCovers "temp_p.jpg"))
    $missingHero    = -not (Test-Path (Join-Path $global:tempCovers "temp_hero.jpg"))
    $missingHeader  = -not (Test-Path (Join-Path $global:tempCovers "temp_header.jpg"))
    $missingLogo    = -not (Test-Path (Join-Path $global:tempCovers "temp_logo.png"))
    # Если PICS уже опрошен выше (для локализованных обложек) и вернул данные —
    # повторно не запрашиваем и те же ссылки не пробуем.
    if (($missingCapsule -or $missingHero -or $missingHeader -or $missingLogo) -and $pics -eq $null) {
        $pics = Get-SteamPicsAssetUrls $cleanAppID $steamLang
        if ($pics -ne $null) {
            if ($missingCapsule) { Save-FirstWorkingUrl $pics.Capsule (Join-Path $global:tempCovers "temp_p.jpg")      | Out-Null }
            if ($missingHero)    { Save-FirstWorkingUrl $pics.Hero    (Join-Path $global:tempCovers "temp_hero.jpg")   | Out-Null }
            if ($missingHeader)  { Save-FirstWorkingUrl $pics.Header  (Join-Path $global:tempCovers "temp_header.jpg") | Out-Null }
            if ($missingLogo)    { Save-FirstWorkingUrl $pics.Logo    (Join-Path $global:tempCovers "temp_logo.png")   | Out-Null }
            foreach ($tempFile in @("temp_p.jpg", "temp_hero.jpg", "temp_logo.png", "temp_header.jpg")) {
                $tempFilePath = Join-Path $global:tempCovers $tempFile
                if ((Test-Path $tempFilePath) -and (Get-Item $tempFilePath).Length -lt 512) {
                    Remove-Item $tempFilePath -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    if ($allowSgdbLogo -and -not (Test-Path (Join-Path $global:tempCovers "temp_logo.png"))) {
        Try-FillMissingLogoFromSteamGridDB $cleanAppID | Out-Null
    }
}

# БАГ-ФИКС: раньше найденный App ID принимался "как есть", даже если у него
# реально скачивался ТОЛЬКО широкий фон (hero) — без вертикальной капсулы
# (library_600x900) и без header. Это верный признак, что App ID указывает
# не на ту игру: у чужой/похожей страницы нашёлся общий фон, но не сама
# обложка (именно так вели себя Planet of Lana II, Plants vs. Zombies:
# Replanted и Resonance: A Plague Tale Legacy). Считаем обложки "нормальными"
# только если скачалась хотя бы капсула ИЛИ header — то, что реально
# показывается в библиотеке Steam.
function Test-CoversValid {
    $hasCapsule = Test-Path (Join-Path $global:tempCovers "temp_p.jpg")
    $hasHeader  = Test-Path (Join-Path $global:tempCovers "temp_header.jpg")
    return ($hasCapsule -or $hasHeader)
}

# Добирает ТОЛЬКО отсутствующие типы обложек из SteamGridDB — Steam остаётся
# основным источником, SGDB лишь закрывает пробелы. Вынесено в отдельную
# функцию (раньше было локальным scriptblock-ом внутри старого окна пакетного
# добавления), т.к. теперь используется и тихим автодобавлением
# (Add-GameToSteamQuietly), и осталась бы полезной для карточки при желании.
function Fill-MissingCoversFromSgdb ($steamAppId) {
    if ([string]::IsNullOrWhiteSpace([string]$steamAppId)) { return }
    if ([string]::IsNullOrWhiteSpace([string]$global:steamGridDbApiKey)) { return }
    try {
        $assets = Get-SteamGridDbAssetsBySteamAppId $steamAppId
        if ($assets -eq $null) { return }
        $targets = @(
            @{ File="temp_p.jpg";      Items=@($assets.Grids | Where-Object {
                $w=0;$h=0;try{$w=[int]$_.width;$h=[int]$_.height}catch{}
                (($w -eq 600 -and $h -eq 900) -or ($w -eq 342 -and $h -eq 482) -or ($w -eq 660 -and $h -eq 930))
            } | Sort-Object @{Expression={try{[double]$_.score}catch{0}};Descending=$true}) },
            @{ File="temp_header.jpg"; Items=@($assets.Grids | Where-Object {
                $w=0;$h=0;try{$w=[int]$_.width;$h=[int]$_.height}catch{}
                (($w -eq 920 -and $h -eq 430) -or ($w -eq 460 -and $h -eq 215))
            } | Sort-Object @{Expression={try{[double]$_.score}catch{0}};Descending=$true}) },
            @{ File="temp_hero.jpg"; Items=@($assets.Heroes | Sort-Object @{Expression={try{[double]$_.score}catch{0}};Descending=$true}) },
            @{ File="temp_logo.png"; Items=@($assets.Logos  | Sort-Object @{Expression={try{[double]$_.score}catch{0}};Descending=$true}) }
        )
        foreach ($target in $targets) {
            $path = Join-Path $global:tempCovers $target.File
            if (Test-Path $path) { continue }
            foreach ($asset in @($target.Items)) {
                if ($null -eq $asset -or [string]::IsNullOrWhiteSpace([string]$asset.url)) { continue }
                if (Download-RemoteImage ([string]$asset.url) $path) { break }
            }
        }
    } catch {}
}

# Тихая (без показа карточки) попытка добавить игру в Steam. Срабатывает
# ТОЛЬКО если программа уверена одновременно и в названии (Steam нашёл точное
# совпадение по имени папки), и в исполняемом файле (единственный кандидат
# или он уже закэширован по этому пути — см. $global:exeSelectionCache) —
# то есть ровно те же условия, при которых в обычной карточке у обоих полей
# горит зелёная галочка (см. Set-ConfidenceBadge / $exeConfidentInitial /
# $titleConfidentInitial внутри Show-GameEditorDialog). Если хоть одно из
# двух не подтверждено уверенно, .Handled=$false — вызывающий код обязан
# показать обычную карточку, чтобы пользователь проверил/поправил вручную.
function Add-GameToSteamQuietly ($game) {
    $result = [PSCustomObject]@{ Handled=$false; Success=$false; Reason='' }

    $steamInfo = $null
    try { $steamInfo = Find-SteamAppInfo $game.Name } catch { $steamInfo = $null }
    if ($steamInfo -eq $null -or [string]::IsNullOrWhiteSpace([string]$steamInfo.Id)) {
        $result.Reason = (T 'reason_title_unconfirmed')
        return $result
    }

    $exeCandidates = @(Get-EditorExecutableCandidates $game.Path)
    if (@($exeCandidates).Count -eq 0) {
        $result.Reason = (T 'reason_exe_missing')
        return $result
    }

    $cacheKey = $game.Path.ToUpper()
    $cached = $null
    try { if ($global:exeSelectionCache.ContainsKey($cacheKey)) { $cached = [string]$global:exeSelectionCache[$cacheKey] } } catch {}
    $idx = -1
    if ($cached) {
        for ($i=0; $i -lt $exeCandidates.Count; $i++) {
            try {
                if ([string]::Equals([string]$exeCandidates[$i].FullName, $cached, [System.StringComparison]::OrdinalIgnoreCase)) { $idx=$i; break }
            } catch {}
        }
    }
    # Та же уверенность, что и $exeConfidentInitial в карточке: уверенно,
    # если выбор взят из кэша или кандидат вообще один — угадывание среди
    # нескольких вариантов без совпадения по кэшу сюда не допускается.
    $exeConfident = ($idx -ge 0) -or ($exeCandidates.Count -le 1)
    $chosenExe = $null
    if (-not $exeConfident) {
        # Несколько кандидатов и нет сохранённого выбора: спрашиваем у Steam,
        # какой файл он считает основным для этого App ID. Подсказка
        # принимается, только если этот файл реально есть в папке игры.
        $hintedExe = $null
        try { $hintedExe = Get-SteamHintedExecutable $game.Path ([string]$steamInfo.Id) } catch { $hintedExe = $null }
        if ($hintedExe -eq $null) {
            $result.Reason = (T 'reason_multi_exe')
            return $result
        }
        $chosenExe = $hintedExe
    } else {
        if ($idx -lt 0) { $idx = 0 }
        $chosenExe = $exeCandidates[$idx]
    }

    # С этого момента решение принято: и название, и EXE определены
    # уверенно — дальше делаем всё без показа карточки.
    $result.Handled = $true

    $steamPathProperty = $null
    try {
        $global:exeSelectionCache[$cacheKey] = $chosenExe.FullName

        $displayName = [string]$steamInfo.Name
        $appId = [string]$steamInfo.Id

        # Обе панели равноправны: автоматическое добавление тоже не переносит
        # игру между папками и не создаёт никаких ссылок. Steam получает реальный
        # путь к игре в той панели, где она находится сейчас.
        $finalExe = $chosenExe.FullName
        $finalStart = $game.Path

        Download-CoversToTemp $appId $false | Out-Null
        Fill-MissingCoversFromSgdb $appId

        $newId = Add-ShortcutToSteam $displayName $finalExe $finalStart ''
        if (-not $newId) {
            $result.Success = $false
            $result.Reason = if ($global:lastShortcutError) { [string]$global:lastShortcutError } else { (T 'reason_shortcut_fail') }
            return $result
        }

        if (Test-CoversValid) { Copy-TempCoversDirectlyToGrid $newId | Out-Null }
        $global:folderDisplayNameCache[$game.Path.ToUpper()] = $displayName
        $result.Success = $true
    } catch {
        $result.Success = $false
        $result.Reason = $_.Exception.Message
    }
    return $result
}
# Вынесено из btnAddToSteam, чтобы этой же логикой мог пользоваться btnApplyCoversNow
# (иначе им пришлось бы искать exe по-разному и получать разные ID)
#
# БАГ-ФИКС: раньше при выборе игры с несколькими exe диалог "Выбор запуска"
# показывался КАЖДЫЙ раз, когда для этой же игры вызывалась Get-GameExecutable —
# то есть один раз при "Добавить в Steam" и ещё раз при "Применить обложки".
# Теперь выбор пользователя (или автоматически найденный exe) кэшируется по
# пути папки игры, и повторный вызов для той же папки просто берёт его из кэша.
$global:exeSelectionCache = @{}
# Запоминает, под каким именно названием (папки или официальным из Steam)
# игра была добавлена ярлыком в текущем сеансе — чтобы кнопка "Применить
# обложки" считала App ID по ТОЙ ЖЕ строке, что реально попала в AppName
# ярлыка при "Добавить выбранные игры в Steam" (иначе ID не совпадёт).
$global:folderDisplayNameCache = @{}

function Get-GameExecutable ($gamePath, $gameName, [scriptblock]$selectorFn = $null) {
    $cacheKey = $gamePath.ToUpper()
    if ($global:exeSelectionCache.ContainsKey($cacheKey)) {
        $cachedPath = $global:exeSelectionCache[$cacheKey]
        if (Test-Path $cachedPath) { return (Get-Item -Path $cachedPath) }
        $global:exeSelectionCache.Remove($cacheKey)
    }

    # БАГ-ФИКС: раньше фильтр отсеивал .exe по ГОЛЫМ подстрокам вроде "crash"
    # или "launcher" — из-за чего под раздачу попадал, например, CrashBandicoot4.exe
    # (это часть НАЗВАНИЯ игры, а не "CrashReporter"), и настоящий exe даже не
    # доходил до диалога выбора. Теперь паттерны куда более точечные: они бьют
    # по конкретным известным служебным утилитам (реран-таймы, крash-репортеры,
    # анти-читы, апдейтеры), а не по случайным словам, которые могут встретиться
    # в имени самой игры. Проверяем полный путь — это ловит ещё и папки вида
    # "_CommonRedist", "Engine\Extras\Redist" независимо от имени самого файла.
    #
    # ДОПОЛНЕНИЕ: папка "\runtimes" целиком (там лежат подпроцессы CefSharp,
    # .NET-раннтаймы и т.п. — никогда не сам исполняемый файл игры), а также
    # конкретные служебные утилиты, которые часто кладут рядом с игрой в папку
    # "\Launcher" (проверщики драйверов/слоёв Vulkan, встроенный браузер
    # лаунчера) — раньше они не отсеивались и засоряли список выбора.
    $junkPattern = '(?i)unins00|\buninstall(er)?\b|unitycrashhandler|crashpad|crashreportclient|crashreporter|crs-handler|crs-uploader|unrealcefsubprocess|\bcefsubprocess\b|\bcefsharp\b|browsersubprocess|driverversionchecker|layerschecker|battleye|easyanticheat|\beac\b|vc_?redist|_?commonredist|\bdotnetfx\b|\bdxsetup\b|\bdirectx\b.*setup|\bprereqsetup\b|physxsetup|vcredist|vulkanrt|\bautorun\b|\bupdater\b|\bpatcher\b|installer\.exe$|_original|_crack|\\Support\\|\\runtimes\\|\\(config|settings|options|cfg)\.exe$'
    
    $allExes = Get-ChildItem -Path $gamePath -Filter "*.exe" -File -Recurse -ErrorAction SilentlyContinue
    $clean = $allExes | Where-Object { $_.FullName -notmatch $junkPattern }
    # Если фильтр случайно отсёк вообще всё (крайний случай) — лучше показать
    # пользователю полный список, чем молча вернуть "exe не найден".
    if ($clean.Count -eq 0) { $clean = $allExes }

    # Приоритет — файлы прямо в КОРНЕ папки игры. Технический мусор (редистрибутивы,
    # установщики движка, крash-репортеры) почти всегда лежит во вложенных папках;
    # настоящий запускаемый файл игры в подавляющем большинстве случаев лежит в корне.
    $rootExes = $clean | Where-Object { $_.DirectoryName.TrimEnd('\') -eq $gamePath.TrimEnd('\') }
    $preOrdered = if ($rootExes.Count -gt 0) { $rootExes } else { $clean }
    # БАГ-ФИКС: см. аналогичное исправление в Get-EditorExecutableCandidates —
    # без этого первый (и, соответственно, выбранный по умолчанию в диалоге
    # выбора) exe определялся чисто алфавитным порядком, а не тем, похож ли
    # файл на лаунчер, из-за чего диалог мог по умолчанию выделять лаунчер
    # вместо прямого запуска игры.
    $launcherLikePattern = '(?i)launcher'
    $candidates = @($preOrdered | Sort-Object `
        @{Expression={ if ($_.FullName -match $launcherLikePattern) { 1 } else { 0 } }}, `
        Name)

    $resultExe = $null
    if ($candidates.Count -eq 1) {
        $resultExe = $candidates
    } elseif ($candidates.Count -gt 1) {
        $exactMatch = $candidates | Where-Object { $gameName -match [System.Text.RegularExpressions.Regex]::Escape($_.BaseName) -or $_.BaseName -match [System.Text.RegularExpressions.Regex]::Escape($gameName) } | Select-Object -First 1
        if ($exactMatch -ne $null) {
            $resultExe = $exactMatch
        } elseif ($selectorFn -ne $null) {
            $resultExe = & $selectorFn $candidates $gamePath $gameName
        } else {
            $resultExe = Show-ExeSelectionDialog $candidates $gamePath $gameName
        }
    } elseif ($allExes.Count -gt 0) {
        $resultExe = ($allExes | Sort-Object Length -Descending | Select-Object -First 1)
    }

    if ($resultExe -ne $null) { $global:exeSelectionCache[$cacheKey] = $resultExe.FullName }
    return $resultExe
}

# БАГ-ФИКС: раньше функция возвращала ТОЛЬКО App ID. Из-за этого при добавлении
# ярлыка в Steam использовалось имя папки на диске, а не настоящее название
# игры из магазина Steam. Теперь возвращается объект с Id И Name сразу —
# оба поля берутся из ОДНОГО и того же найденного элемента поиска, так что
# они гарантированно относятся к одной и той же игре.
function Start-PumpedSleep ([int]$milliseconds) {
    # Обычный Start-Sleep держит поток мёртво — даже DoEvents() до/после него
    # не спасает от замирания спиннера ровно на время паузы. Здесь та же
    # пауза, но нарезанная на маленькие кусочки с прокачкой очереди сообщений
    # между ними — сеть это никак не трогает, поэтому риска нет.
    $deadline = (Get-Date).AddMilliseconds([Math]::Max(0, $milliseconds))
    while ((Get-Date) -lt $deadline) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 20
    }
}

function Find-SteamAppInfo ($gameName) {
    $global:lastAppIdSearchError = $null
    $normTarget = Get-NormalizedGameKey $gameName
    $targetTokens = Get-NameTokens $gameName

    # ===== 1) Онлайн-поиск витрины Steam (storesearch) =====
    $searchTerm = [System.Uri]::EscapeDataString($gameName)
    $url = "https://store.steampowered.com/api/storesearch/?term=$searchTerm&l=english&cc=us"

    # БАГ-ФИКС: раньше запрос шёл через "curl.exe | ConvertFrom-Json" внутри
    # общего try/catch — при любом сбое (сетевой сбой, временный бан/лимит
    # запросов от Steam, "проглоченный" вывод curl из-за построчного захвата
    # в PowerShell) функция молча возвращала null, и было не понять, это
    # "игры правда нет в Steam" или "запрос не удался". Крупные, абсолютно
    # реальные игры (DiRT 4, Diablo II Resurrected и т.п.) не должны были
    # не находиться в принципе — значит, дело было именно в запросе, а не
    # в сравнении названий.
    #
    # ВАЖНЫЙ НЮАНС: Invoke-RestMethod использует TLS-настройки самого .NET/
    # Windows PowerShell 5.1, а там TLS 1.2 для исходящих HTTPS-запросов
    # по умолчанию иногда НЕ включён (устаревшее системное значение) — тогда
    # Invoke-RestMethod тихо падает с ошибкой соединения, хотя curl.exe
    # (у него свой собственный стек TLS, не зависящий от настроек .NET)
    # прекрасно работает. Поэтому: сначала явно форсируем TLS 1.2/1.3,
    # а если Invoke-RestMethod всё равно не прошёл — откатываемся на curl.exe
    # как запасной вариант (соединяем многострочный вывод ДО ConvertFrom-Json,
    # чтобы PowerShell не разбил JSON на массив строк построчно).
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch {}

    # БАГ-ФИКС (зависание первой карточки): раньше этот запрос шёл прямым
    # блокирующим Invoke-RestMethod прямо в UI-потоке. На первой карточке за
    # сеанс к этому добавлялись "холодный старт" командлета и первое TLS-
    # соединение, и интерфейс со спиннером замирал. Теперь запрос (вместе с
    # запасным curl.exe) выполняется в фоновом runspace через
    # Invoke-BackgroundJsonRequest, а UI-поток прокачивает очередь сообщений.
    $storeSearchRequest = {
        param($u)
        try {
            return (Invoke-RestMethod -Uri $u -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -TimeoutSec 10 -ErrorAction Stop)
        } catch {
            try {
                $rawLines = curl.exe -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" --connect-timeout 8 --max-time 12 $u
                $rawJson = ($rawLines -join "")
                if (-not [string]::IsNullOrWhiteSpace($rawJson)) { return ($rawJson | ConvertFrom-Json -ErrorAction Stop) }
            } catch {}
            return $null
        }
    }

    $data = $null
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        $data = Invoke-BackgroundJsonRequest $storeSearchRequest @($url) 25
        if ($data -ne $null) { break }
        $global:lastAppIdSearchError = "storesearch: нет ответа от сервера"
        if ($attempt -lt 2) { Start-PumpedSleep 900 }
    }
    if ($data -eq $null) { return $null }

    # БАГ-ФИКС: пустой результат ("total=0") от storesearch не всегда значит,
    # что игры правда нет в Steam — витрина иногда временно "тупит" на
    # конкретный запрос при частых подряд обращениях (пакетное добавление
    # многих игр). Прежде чем сдаваться, ждём и пробуем тот же запрос ещё раз.
    if ($data.total -lt 1 -or $data.items.Count -eq 0) {
        Start-PumpedSleep 1500
        $data2 = Invoke-BackgroundJsonRequest $storeSearchRequest @($url) 25
        if ($data2 -ne $null -and $data2.total -ge 1 -and $data2.items.Count -gt 0) { $data = $data2 }
    }
    if ($data.total -lt 1 -or $data.items.Count -eq 0) { $global:lastAppIdSearchError = "поиск не вернул результатов"; return $null }

    # БАГ-ФИКС: раньше при отсутствии точного совпадения слепо брался ПЕРВЫЙ
    # результат поиска — а это могла быть совершенно другая игра (поиск Steam
    # не идеален, особенно с апострофами/двоеточиями/приставками "Collection",
    # "Edition" и т.п.). Теперь сравниваем через ту же нормализацию, что и для
    # подсветки "уже установленных" игр (Get-NormalizedGameKey — убирает всю
    # пунктуацию, пробелы и регистр), и если ничего толком не похоже —
    # честно возвращаем "не найдено", а не подсовываем обложку не той игры.
    # ($normTarget и $targetTokens уже вычислены выше.)

    $exact = $data.items | Where-Object { (Get-NormalizedGameKey $_.name) -eq $normTarget } | Select-Object -First 1
    if ($exact -ne $null) { return [PSCustomObject]@{ Id = [string]$exact.id; Name = [string]$exact.name } }

    # Одно название — префикс другого (у нас "Resident Evil 4", в Steam —
    # "Resident Evil 4 Gold Edition" или наоборот). Из всех подходящих под
    # это условие берём тот, чья длина ближе всего к искомой — так меньше
    # риска зацепить непричастную игру с длинным похожим названием.
    #
    # БАГ-ФИКС: раньше здесь не было проверки НАСКОЛЬКО короче одно название
    # другого — из-за этого короткое реальное название вроде "Resonance"
    # (это префикс ЛЮБОЙ строки, начинающейся с этих букв) ложно "совпадало"
    # с папкой вроде "Resonance A Plague Tale Legacy" (склеенное/странное имя
    # папки на диске, не являющееся одной реальной игрой), и в Steam
    # добавлялось совершенно чужое, но похожее по первым буквам название.
    # Теперь совпадение по префиксу/суффиксу засчитывается, только если
    # короткое название покрывает не менее ~65% длины длинного — этого
    # достаточно для случаев вроде "+ Gold/Definitive/Complete Edition",
    # но отсекает совпадения по одному случайно похожему первому слову.
    $prefixMatch = $data.items | Where-Object {
        $nc = Get-NormalizedGameKey $_.name
        if ([string]::IsNullOrEmpty($nc)) { return $false }
        if (-not ($nc.StartsWith($normTarget) -or $normTarget.StartsWith($nc))) { return $false }
        $shorterLen = [Math]::Min($nc.Length, $normTarget.Length)
        $longerLen = [Math]::Max($nc.Length, $normTarget.Length)
        if ($longerLen -eq 0) { return $false }
        return (($shorterLen / [double]$longerLen) -ge 0.65)
    } | Sort-Object { [Math]::Abs(([int](Get-NormalizedGameKey $_.name).Length) - [int]$normTarget.Length) } | Select-Object -First 1
    if ($prefixMatch -ne $null) { return [PSCustomObject]@{ Id = [string]$prefixMatch.id; Name = [string]$prefixMatch.name } }

    # Последний резерв: нечёткий алгоритм "общие значимые слова"
    # (см. Get-NameTokens / Get-TokenOverlapScore) по результатам storesearch —
    # ловит случаи, где точного/префиксного совпадения нет, но по смыслу
    # слов результат явно тот же самый. Плюс та же проверка на полное
    # вхождение слов папки в название кандидата — для случаев вроде
    # подзаголовка, отсутствующего в имени папки на диске (например, папка
    # "Crash Bandicoot 4" против "Crash Bandicoot 4: It's About Time").
    $best = $null; $bestScore = 0.0
    $bestContainment = $null; $bestContainmentExtra = [int]::MaxValue
    foreach ($it in $data.items) {
        $itTokens = Get-NameTokens $it.name
        $score = Get-TokenOverlapScore $targetTokens $itTokens
        if ($score -gt $bestScore) { $bestScore = $score; $best = $it }
        if ($targetTokens.Count -ge 2) {
            $itSet = New-Object 'System.Collections.Generic.HashSet[string]'
            foreach ($t in $itTokens) { [void]$itSet.Add($t) }
            $containsAll = $true
            foreach ($t in $targetTokens) { if (-not $itSet.Contains($t)) { $containsAll = $false; break } }
            if ($containsAll) {
                $extra = $itTokens.Count - $targetTokens.Count
                if ($extra -lt $bestContainmentExtra) { $bestContainmentExtra = $extra; $bestContainment = $it }
            }
        }
    }
    if ($best -ne $null -and $bestScore -ge 0.6) {
        return [PSCustomObject]@{ Id = [string]$best.id; Name = [string]$best.name }
    }
    if ($bestContainment -ne $null) {
        return [PSCustomObject]@{ Id = [string]$bestContainment.id; Name = [string]$bestContainment.name }
    }

    # ===== 2) Запасной вариант — подсказки поиска витрины (search/suggest) =====
    # storesearch сортирует по общей популярности/продажам, а не по точному
    # совпадению текста — и для названия из одного распространённого слова
    # (например "Keeper": в Steam ещё есть "Graveyard Keeper", "Dungeon
    # Keeper", "Zoo Keeper" и т.п.) может просто не включить нужную игру в
    # свою (ограниченную) первую страницу результатов, даже если сама игра
    # прекрасно есть в Steam. Подсказки поиска (то же самое, что выпадающий
    # список при вводе текста в строке поиска на сайте Steam) сортируют в
    # первую очередь по релевантности самого текста запроса — для короткого/
    # частого названия это обычно куда точнее.
    try {
        $suggestUrl = "https://store.steampowered.com/search/suggest?term=$searchTerm&f=games&cc=us&l=english&realm=1"
        $suggestRequest = {
            param($u)
            try {
                return [string](Invoke-RestMethod -Uri $u -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -TimeoutSec 10 -ErrorAction Stop)
            } catch {
                try {
                    $rawLines = curl.exe -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" --connect-timeout 8 --max-time 12 $u
                    return [string]($rawLines -join "`n")
                } catch {}
                return $null
            }
        }
        $suggestHtml = Invoke-BackgroundJsonRequest $suggestRequest @($suggestUrl) 20
        if (-not [string]::IsNullOrWhiteSpace([string]$suggestHtml)) {
            $suggestMatches = [System.Text.RegularExpressions.Regex]::Matches(
                [string]$suggestHtml,
                'data-ds-appid="(\d+)"[\s\S]*?class="match_name">([^<]+)<'
            )
            $suggestItems = New-Object System.Collections.Generic.List[object]
            foreach ($m in $suggestMatches) {
                $sName = [System.Net.WebUtility]::HtmlDecode($m.Groups[2].Value.Trim())
                $suggestItems.Add([PSCustomObject]@{ id = $m.Groups[1].Value; name = $sName })
            }
            if ($suggestItems.Count -gt 0) {
                $sExact = $suggestItems | Where-Object { (Get-NormalizedGameKey $_.name) -eq $normTarget } | Select-Object -First 1
                if ($sExact -ne $null) { return [PSCustomObject]@{ Id = [string]$sExact.id; Name = [string]$sExact.name } }

                $sBest = $null; $sBestScore = 0.0
                foreach ($it in $suggestItems) {
                    $score = Get-TokenOverlapScore $targetTokens (Get-NameTokens $it.name)
                    if ($score -gt $sBestScore) { $sBestScore = $score; $sBest = $it }
                }
                if ($sBest -ne $null -and $sBestScore -ge 0.6) {
                    return [PSCustomObject]@{ Id = [string]$sBest.id; Name = [string]$sBest.name }
                }
            }
        }
    } catch {}

    $global:lastAppIdSearchError = "ни одно название в результатах поиска не похоже на '$gameName'"
    return $null
}

# ===================== Steam — собственный поиск ВАРИАНТОВ названия =====================
# Раньше выпадающий список вариантов названия при источнике "Steam" (карточка
# добавления игры) заполнялся через Get-EditorSgdbCandidates — автодополнение
# SteamGridDB, для которого нужен личный API-ключ. Из-за этого поиск по Steam
# был самостоятельным только для ОДНОГО найденного App ID (Find-SteamAppInfo),
# а сам список вариантов для выбора — уже нет: без ключа SGDB он оставался
# пустым, даже когда сам Steam прекрасно находил нужную игру.
#
# Эта функция даёт источнику Steam полностью свой список вариантов, без
# какого-либо ключа и без SteamGridDB: берётся онлайн-поиск витрины Steam
# (storesearch), сохраняются ВСЕ подходящие элементы, а порядок, в котором
# их возвращает сама витрина Steam, — это и есть её собственная "логика
# совпадений": он просто переносится в скор для сортировки, а не
# переизобретается заново.
# Каждый вариант несёт СВОЙ настоящий Steam App ID, поэтому при выборе из
# списка повторный поиск App ID по названию уже не требуется.
function Get-SteamStoreNameCandidates ([string]$query, [int]$limit = 12) {
    $q = ([string]$query).Trim()
    if ($q.Length -lt 2) { return @() }

    $results = New-Object System.Collections.Generic.List[object]
    $seenIds = New-Object 'System.Collections.Generic.HashSet[string]'

    # ===== Онлайн-поиск витрины Steam (storesearch), без ключа =====
    if ($results.Count -lt $limit) {
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
        $searchTerm = [System.Uri]::EscapeDataString($q)
        $url = "https://store.steampowered.com/api/storesearch/?term=$searchTerm&l=english&cc=us"
        $data = $null
        try {
            $data = Invoke-RestMethod -Uri $url -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -TimeoutSec 8 -ErrorAction Stop
        } catch {
            try {
                $rawLines = curl.exe -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" $url
                $rawJson = ($rawLines -join "")
                if (-not [string]::IsNullOrWhiteSpace($rawJson)) { $data = $rawJson | ConvertFrom-Json -ErrorAction Stop }
            } catch {}
        }
        if ($data -ne $null -and $data.items -ne $null) {
            $rank = 0
            foreach ($it in $data.items) {
                $rank++
                $id = [string]$it.id
                $nm = [string]$it.name
                if ([string]::IsNullOrWhiteSpace($id) -or [string]::IsNullOrWhiteSpace($nm)) { continue }
                if (-not $seenIds.Add($id)) { continue }
                # Позиция в выдаче storesearch = ранг релевантности от самого
                # Steam. Переводим её в убывающий скор, чтобы сортировка ниже
                # совпадала именно с порядком витрины, а не с локальным
                # скорингом по словам.
                $score = [Math]::Max(0.05, 0.78 - ($rank * 0.03))
                $results.Add([PSCustomObject]@{ Id = $id; Name = $nm; MatchScore = [double]$score })
            }
        }
    }

    return @($results | Sort-Object MatchScore -Descending | Select-Object -First $limit)
}

# ===================== SteamGridDB — РЕЗЕРВНЫЙ ИСТОЧНИК ОБЛОЖЕК =====================
# Официальный CDN Steam (store_item_assets) отдаёт обложки только для игр, у
# которых Valve сама сгенерировала полный набор картинок — для части изданий
# (переиздания, менее популярные игры, издания без "капсулы" 600x900) там
# реально лежит только широкий фон (hero), без вертикальной обложки. Test-CoversValid
# ловит эту ситуацию, но раньше выходом было только "ввести App ID вручную",
# что не помогает, если сам Steam обложку не хранит вообще. SteamGridDB — база
# обложек, собранная сообществом именно для таких случаев (в том числе для
# нестимовских игр); ниже — её поддержка с ручным выбором миниатюры.
#
# Нужен бесплатный личный API-ключ (steamgriddb.com -> Preferences -> API).
function Ensure-SteamGridDbApiKey {
    # Ввод и изменение ключа выполняются только в окне «Настройки».
    # Эта функция оставлена как единая точка чтения ключа для существующего кода.
    return [string]$global:steamGridDbApiKey
}

# Ищет игру в SteamGridDB, показывает миниатюры доступных вертикальных
# обложек и по выбору пользователя скачивает выбранную (плюс, по возможности,
# первые доступные hero/logo) напрямую в $global:tempCovers. Возвращает
# объект с полями Name/Id/SkipDownload=$true (готовые обложки уже лежат в
# temp, повторно скачивать их с CDN Steam не нужно) либо $null при отмене.
function Get-SgdbNameScore ($query, $candidate) {
    $q = ([string]$query).ToLowerInvariant().Trim()
    $c = ([string]$candidate.name).ToLowerInvariant().Trim()
    if ([string]::IsNullOrWhiteSpace($q) -or [string]::IsNullOrWhiteSpace($c)) { return 0 }

    function Normalize-SgdbTitle([string]$t) {
        $x = $t.ToLowerInvariant()
        $x = $x -replace '[^\p{L}\p{Nd}]+', ' '
        $x = $x -replace '\s+', ' '
        return $x.Trim()
    }

    $nq = Normalize-SgdbTitle $q
    $nc = Normalize-SgdbTitle $c
    if ($nq -eq $nc) { return 1000 }

    $qTokens = @($nq -split ' ' | Where-Object { $_ })
    $cTokens = @($nc -split ' ' | Where-Object { $_ })
    $common = 0
    foreach ($t in $qTokens) { if ($cTokens -contains $t) { $common++ } }
    $tokenScore = if ($qTokens.Count -gt 0 -and $cTokens.Count -gt 0) {
        (2.0 * $common / ($qTokens.Count + $cTokens.Count)) * 100
    } else { 0 }

    # Нормированная Levenshtein similarity — только для сортировки результатов.
    $a=$nq; $b=$nc; $la=$a.Length; $lb=$b.Length
    if ($la -eq 0 -or $lb -eq 0) { $lev=0 } else {
        $prev=New-Object int[] ($lb+1); $cur=New-Object int[] ($lb+1)
        for($j=0;$j -le $lb;$j++){ $prev[$j]=$j }
        for($i=1;$i -le $la;$i++){
            $cur[0]=$i
            for($j=1;$j -le $lb;$j++){
                $cost=if($a[$i-1] -eq $b[$j-1]){0}else{1}
                $cur[$j]=[Math]::Min([Math]::Min($cur[$j-1]+1,$prev[$j]+1),$prev[$j-1]+$cost)
            }
            $tmp=$prev;$prev=$cur;$cur=$tmp
        }
        $lev=(1.0-($prev[$lb]/[double][Math]::Max($la,$lb)))*100
    }

    $containsBonus = if ($nc.Contains($nq) -or $nq.Contains($nc)) { 18 } else { 0 }
    $typeBonus = if (@($candidate.types) -contains 'steam') { 8 } else { 0 }
    $verifiedBonus = if ($candidate.verified -eq $true) { 6 } else { 0 }
    return [Math]::Round(($tokenScore*0.52)+($lev*0.30)+$containsBonus+$typeBonus+$verifiedBonus,2)
}

function Get-SgdbAssetsForGame ($gameId, $headers) {
    # ВАЖНО: не полагаемся на серверный фильтр dimensions=...
    # У SteamGridDB для разных игр набор размеров может отличаться. Для части
    # игр фильтр возвращал пустой массив, хотя обычный /grids/game/{id}
    # прекрасно отдаёт вертикальные/горизонтальные варианты.
    # Поэтому получаем grids без жёсткого dimensions-фильтра и фильтруем
    # размеры локально. Это также позволяет поддержать альтернативные
    # стандартные размеры SGDB: 342x482 / 660x930 и 460x215.
    $result = [ordered]@{ GridsVertical=@(); GridsHorizontal=@(); Heroes=@(); Logos=@() }

    $gridsReq = Invoke-SgdbApiRequest "https://www.steamgriddb.com/api/v2/grids/game/$gameId" $headers 20
    if ($gridsReq.Success) {
            $all=@($gridsReq.Data)
            $vertical=@($all | Where-Object {
                $w=0;$h=0
                try{$w=[int]$_.width;$h=[int]$_.height}catch{}
                (($w -eq 600 -and $h -eq 900) -or
                 ($w -eq 342 -and $h -eq 482) -or
                 ($w -eq 660 -and $h -eq 930))
            })
            $horizontal=@($all | Where-Object {
                $w=0;$h=0
                try{$w=[int]$_.width;$h=[int]$_.height}catch{}
                (($w -eq 920 -and $h -eq 430) -or
                 ($w -eq 460 -and $h -eq 215))
            })

            # Крайний fallback: если SGDB прислал нестандартный, но явно
            # подходящий по соотношению сторон static grid — тоже покажем его.
            if($vertical.Count -eq 0){
                $vertical=@($all | Where-Object {
                    $w=0;$h=0;try{$w=[double]$_.width;$h=[double]$_.height}catch{}
                    $h -gt 0 -and ($w/$h) -ge 0.55 -and ($w/$h) -le 0.78
                })
            }
            if($horizontal.Count -eq 0){
                $horizontal=@($all | Where-Object {
                    $w=0;$h=0;try{$w=[double]$_.width;$h=[double]$_.height}catch{}
                    $h -gt 0 -and ($w/$h) -ge 1.85 -and ($w/$h) -le 2.35
                })
            }

            $sortByScore = {
                $v=0.0
                try{$v=[double]$_.score}catch{}
                $v
            }
            $result.GridsVertical=@($vertical | Sort-Object $sortByScore -Descending)
            $result.GridsHorizontal=@($horizontal | Sort-Object $sortByScore -Descending)
    }

    foreach($req in @(
        @{ Name='Heroes'; Url="https://www.steamgriddb.com/api/v2/heroes/game/$gameId" },
        @{ Name='Logos'; Url="https://www.steamgriddb.com/api/v2/logos/game/$gameId" }
    )) {
        $r = Invoke-SgdbApiRequest $req.Url $headers 20
        if ($r.Success) {
            $result[$req.Name]=@($r.Data | Sort-Object @{Expression={
                $v=0.0;try{$v=[double]$_.score}catch{};$v
            };Descending=$true})
        }
    }
    return [PSCustomObject]$result
}

# ===================== АНИМАЦИЯ ЗАГРУЗКИ МИНИАТЮР =====================
# Раньше "анимацией" был Label, которому таймер по кругу подставлял символы
# (⟳/⟲ в окнах SteamGridDB и ◌◔◑◕ в карточке игры). Это не вращалось, а
# мигало, зависело от наличия глифов в шрифте и в карточке игры вообще не
# работало (см. фикс в Start-EditorLoading).
#
# Теперь спиннер — отдельная панель, которая рисует себя сама через GDI+:
# по кругу бежит дуга поверх тусклого кольца, а если загрузка не удалась —
# рисуется крестик (или прочерк, если ссылки на миниатюру вообще не было).
# Панель кладётся ПОВЕРХ PictureBox миниатюры, поэтому анимация видна на
# каждой миниатюре отдельно, ровно пока грузится именно она.
#
# Всё состояние хранится в $spinner.Tag (обычный hashtable), а не в
# NoteProperty: Tag — настоящее свойство .NET, поэтому оно доступно и внутри
# обработчика Paint, куда PowerShell передаёт "голый" объект контрола.
function New-CoverSpinner {
    param($target, $accentColor = $null, [int]$maxDiameter = 44)

    if ($null -eq $accentColor) { $accentColor = [System.Drawing.Color]::FromArgb(102,192,244) }

    $sp = New-Object System.Windows.Forms.Panel
    $sp.Dock = 'Fill'
    try { if ($null -ne $target) { $sp.BackColor = $target.BackColor } } catch {}
    $sp.Tag = @{ State = 'loading'; Angle = 0; Accent = $accentColor; Max = $maxDiameter }

    # Двойная буферизация: без неё дуга заметно мерцает при перерисовке.
    try {
        $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic
        [System.Windows.Forms.Control].GetProperty('DoubleBuffered', $flags).SetValue($sp, $true, $null)
    } catch {}

    $sp.Add_Paint({
        param($ctl, $e)
        try {
            $st = $ctl.Tag
            if ($null -eq $st) { return }
            $g = $e.Graphics
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

            $w = $ctl.ClientSize.Width
            $h = $ctl.ClientSize.Height
            $side = [Math]::Min($w, $h)
            if ($side -lt 12) { return }
            $d = [Math]::Min([int]$st.Max, [int]($side * 0.55))
            if ($d -lt 10) { $d = [Math]::Max(10, [int]($side * 0.6)) }
            $x = [int](($w - $d) / 2)
            $y = [int](($h - $d) / 2)
            $rect = New-Object System.Drawing.Rectangle -ArgumentList $x, $y, $d, $d
            $thickness = [double][Math]::Max(2.0, $d / 9.0)
            $accent = [System.Drawing.Color]$st.Accent

            if ([string]$st.State -eq 'loading') {
                $trackColor = [System.Drawing.Color]::FromArgb(60, $accent.R, $accent.G, $accent.B)
                $trackPen = New-Object System.Drawing.Pen -ArgumentList $trackColor, $thickness
                $g.DrawEllipse($trackPen, $rect)
                $trackPen.Dispose()

                $arcPen = New-Object System.Drawing.Pen -ArgumentList $accent, $thickness
                $arcPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
                $arcPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
                $g.DrawArc($arcPen, $rect, [float]$st.Angle, [float]95)
                $arcPen.Dispose()
            }
            else {
                $failPen = New-Object System.Drawing.Pen -ArgumentList ([System.Drawing.Color]::FromArgb(145,154,164)), $thickness
                $g.DrawEllipse($failPen, $rect)
                $pad = [int]($d * 0.3)
                if ([string]$st.State -eq 'empty') {
                    $g.DrawLine($failPen, ($x + $pad), ($y + [int]($d / 2)), ($x + $d - $pad), ($y + [int]($d / 2)))
                } else {
                    $g.DrawLine($failPen, ($x + $pad), ($y + $pad), ($x + $d - $pad), ($y + $d - $pad))
                    $g.DrawLine($failPen, ($x + $d - $pad), ($y + $pad), ($x + $pad), ($y + $d - $pad))
                }
                $failPen.Dispose()
            }
        } catch {}
    })

    return $sp
}

# Один шаг анимации. Вызывается из уже существующих UI-таймеров — отдельных
# потоков по-прежнему нет, поэтому старое правило "никаких обращений к
# WinForms из фона" не нарушается.
function Step-CoverSpinner($spinner) {
    if ($null -eq $spinner) { return }
    try {
        $st = $spinner.Tag
        if ($null -eq $st -or [string]$st.State -ne 'loading') { return }
        if (-not $spinner.Visible) { return }
        $st.Angle = ([int]$st.Angle + 22) % 360
        $spinner.Invalidate()
    } catch {}
}

# Состояния: loading (крутится), done (прячем — миниатюра загрузилась),
# failed (крестик), empty (прочерк, ссылки не было вовсе).
function Set-CoverSpinnerState($spinner, [string]$state) {
    if ($null -eq $spinner) { return }
    try {
        $st = $spinner.Tag
        if ($null -eq $st) { $st = @{ State = $state; Angle = 0; Accent = [System.Drawing.Color]::FromArgb(102,192,244); Max = 44 }; $spinner.Tag = $st }
        $st.State = $state
        if ($state -eq 'done') {
            $spinner.Visible = $false
        } else {
            $spinner.Visible = $true
            $spinner.Invalidate()
        }
    } catch {}
}

function Show-SgdbAssetChooser ($title, [array]$items, [int]$thumbWidth, [int]$thumbHeight, $owner) {
    $items=@($items)
    if($items.Count -eq 0){return $null}

    $dlg=New-Object System.Windows.Forms.Form
    $dlg.Text="SteamGridDB — $title"
    try { $sgdbIco = Get-SteamGridDbFormIcon; if ($null -ne $sgdbIco) { $dlg.Icon = $sgdbIco } } catch {}
    # ВАЖНО про тёмный отступ снизу: раньше здесь стоял жёстко заданный
    # $dlg.Size=1040x720, который не совпадал с реальной высотой контента
    # (особенно при масштабировании экрана — Windows пересчитывает Size формы
    # и расположение дочерних элементов не всегда синхронно, из-за чего под
    # кнопкой «Отмена» оставалась пустая полоса фона). Теперь точный размер
    # окна выставляется в конце функции — по фактическим границам добавленных
    # элементов (после $btnClose), поэтому низ окна всегда совпадает с низом
    # кнопки «Отмена», а не с произвольным числом.
    $dlg.MinimumSize=New-Object System.Drawing.Size(820,560)
    $dlg.StartPosition="CenterParent"
    $dlg.FormBorderStyle="Sizable"
    $dlg.AutoScaleMode=[System.Windows.Forms.AutoScaleMode]::Font
    $dlg.BackColor=[System.Drawing.Color]::FromArgb(23,29,37)
    $dlg.ForeColor=[System.Drawing.Color]::FromArgb(220,223,228)
    $dlg.Font=New-Object System.Drawing.Font("Segoe UI",9)

    $lbl=New-Object System.Windows.Forms.Label
    $lbl.Text=(T 'sgdb_chooser_hint')
    $lbl.Location=New-Object System.Drawing.Point(15,12)
    $lbl.Size=New-Object System.Drawing.Size(990,25)
    $lbl.Font=New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
    $lbl.ForeColor=[System.Drawing.Color]::FromArgb(220,223,228)
    $dlg.Controls.Add($lbl)

    # Область миниатюр. Обычный Panel + ручной перенос строк: это надёжнее
    # FlowLayoutPanel при AutoScroll и не создаёт горизонтальный диапазон.
    $flow=New-Object System.Windows.Forms.Panel
    $flow.Location=New-Object System.Drawing.Point(12,45)
    $flow.Size=New-Object System.Drawing.Size(1000,580)
    $flow.Anchor='Top,Bottom,Left,Right'
    $flow.AutoScroll=$true
    $flow.BackColor=[System.Drawing.Color]::FromArgb(23,29,37)
    $flow.HorizontalScroll.Enabled=$false
    $flow.HorizontalScroll.Visible=$false
    $dlg.Controls.Add($flow)

    # ВАЖНО: никаких Process.Exited/BeginInvoke и никаких фоновых обращений к WinForms.
    # Process.Exited у PowerShell может выполняться вне UI-потока и приводить к тихому
    # падению WinForms. Вместо этого UI Timer периодически проверяет завершившиеся curl.
    $dialogState=@{Result=$null;Clients=New-Object System.Collections.ArrayList;SpinIndex=0;Closed=$false}
    $maxItems=[Math]::Min(40,$items.Count)

    for($j=0;$j -lt $maxItems;$j++){
        $item=$items[$j]
        $url='';$thumbUrl=''
        try {
            if($null -ne $item.PSObject.Properties['url']) {$url=[string]$item.PSObject.Properties['url'].Value}
            if($null -ne $item.PSObject.Properties['thumb']) {$thumbUrl=[string]$item.PSObject.Properties['thumb'].Value}
            if([string]::IsNullOrWhiteSpace($url) -and $null -ne $item.PSObject.Properties['grid_url']) {$url=[string]$item.PSObject.Properties['grid_url'].Value}
            if([string]::IsNullOrWhiteSpace($thumbUrl) -and $null -ne $item.PSObject.Properties['grid_url_thumbnail']) {$thumbUrl=[string]$item.PSObject.Properties['grid_url_thumbnail'].Value}
        } catch {}
        if([string]::IsNullOrWhiteSpace($thumbUrl)){$thumbUrl=$url}
        if([string]::IsNullOrWhiteSpace($url)){$url=$thumbUrl}

        $card=New-Object System.Windows.Forms.Panel
        $cardWidth=$thumbWidth+14
        $cardHeight=$thumbHeight+42
        $card.Size=New-Object System.Drawing.Size($cardWidth,$cardHeight)

        # Рассчитываем число колонок по фактической ширине области.
        # Для вертикальных (170 px) получается 5 колонок; для широких
        # Horizontal/Hero/Logo (270 px) — 3 колонки. Остальные карточки
        # автоматически переходят на следующую строку.
        $availableWidth=[Math]::Max(1,$flow.ClientSize.Width-12)
        $cellWidth=[Math]::Max(1,$cardWidth+10)
        $columns=[Math]::Max(1,[int][Math]::Floor(($availableWidth+10)/$cellWidth))
        $col=$j % $columns
        $row=[int][Math]::Floor($j/$columns)
        $x=10+($col*$cellWidth)
        $y=10+($row*($cardHeight+13))
        $card.Location=New-Object System.Drawing.Point([int]$x,[int]$y)
        $card.BorderStyle=[System.Windows.Forms.BorderStyle]::FixedSingle
        $card.BackColor=[System.Drawing.Color]::FromArgb(27,40,56)
        $flow.Controls.Add($card)

        $pb=New-Object System.Windows.Forms.PictureBox
        $pb.Location=New-Object System.Drawing.Point(5,5)
        $pb.Size=New-Object System.Drawing.Size($thumbWidth,$thumbHeight)
        $pb.SizeMode=[System.Windows.Forms.PictureBoxSizeMode]::Zoom
        $pb.BorderStyle=[System.Windows.Forms.BorderStyle]::FixedSingle
        $pb.BackColor=[System.Drawing.Color]::FromArgb(13,20,28)
        $pb.Cursor=[System.Windows.Forms.Cursors]::Hand
        $pb.Tag=$url
        $card.Controls.Add($pb)

        # Анимация загрузки поверх конкретно этой миниатюры.
        $spinner=New-CoverSpinner $pb ([System.Drawing.Color]::FromArgb(102,192,244)) 46
        $pb.Controls.Add($spinner)

        $num=New-Object System.Windows.Forms.Label
        $num.Text="#" + ($j+1)
        $num.Location=New-Object System.Drawing.Point(5,($thumbHeight+10))
        $num.Size=New-Object System.Drawing.Size($thumbWidth,22)
        $num.TextAlign='MiddleCenter'
        $num.ForeColor=[System.Drawing.Color]::FromArgb(145,154,164)
        $card.Controls.Add($num)

        $pb.Add_Click({
            try {
                $picked=[string]$this.Tag
                if(-not [string]::IsNullOrWhiteSpace($picked)){
                    $dialogState.Result=$picked
                    $dlg.DialogResult=[System.Windows.Forms.DialogResult]::OK
                    $dlg.Close()
                }
            } catch {}
        })

        if(-not [string]::IsNullOrWhiteSpace($thumbUrl)){
            try {
                $tmp=[System.IO.Path]::Combine($global:tempCovers,('sgdb_chooser_{0}.tmp' -f [guid]::NewGuid().ToString('N')))
                $psi=New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName='curl.exe'
                $psi.Arguments='-L --silent --show-error --fail --max-time 20 -A "{2}/{3}" -o "{0}" "{1}"' -f $tmp,$thumbUrl,$global:appTitle,$global:appVersion
                $psi.UseShellExecute=$false
                $psi.CreateNoWindow=$true
                $proc=New-Object System.Diagnostics.Process
                $proc.StartInfo=$psi
                $proc | Add-Member -NotePropertyName TargetPictureBox -NotePropertyValue $pb -Force
                $proc | Add-Member -NotePropertyName TargetSpinner -NotePropertyValue $spinner -Force
                $proc | Add-Member -NotePropertyName TempFile -NotePropertyValue $tmp -Force
                $proc | Add-Member -NotePropertyName TargetUrl -NotePropertyValue $url -Force
                $proc | Add-Member -NotePropertyName DoneHandled -NotePropertyValue $false -Force
                [void]$dialogState.Clients.Add($proc)
                [void]$proc.Start()
            } catch {
                Set-CoverSpinnerState $spinner 'failed'
            }
        } else {
            Set-CoverSpinnerState $spinner 'empty'
        }
    }

    # Задаём минимальную высоту содержимого, чтобы при большом количестве
    # вариантов появлялась именно вертикальная полоса прокрутки.
    $cardHeightForScroll=$thumbHeight+42
    $availableWidthForScroll=[Math]::Max(1,$flow.ClientSize.Width-12)
    $cellWidthForScroll=[Math]::Max(1,$thumbWidth+14+10)
    $columnsForScroll=[Math]::Max(1,[int][Math]::Floor(($availableWidthForScroll+10)/$cellWidthForScroll))
    $rowsForScroll=[int][Math]::Ceiling($maxItems/[double]$columnsForScroll)
    $contentHeight=10+($rowsForScroll*$cardHeightForScroll)+(($rowsForScroll-1)*13)+10
    $flow.AutoScrollMinSize=New-Object System.Drawing.Size(1,[int]$contentHeight)
    $flow.HorizontalScroll.Enabled=$false
    $flow.HorizontalScroll.Visible=$false

    # Явно задаём высоту содержимого, чтобы при большом количестве
    # вариантов появлялась вертикальная прокрутка, а горизонтальная была
    # полностью исключена.
    $scrollCardHeight=$thumbHeight+42
    $scrollAvailableWidth=[Math]::Max(1,$flow.ClientSize.Width-12)
    $scrollCellWidth=[Math]::Max(1,$thumbWidth+14+10)
    $scrollColumns=[Math]::Max(1,[int][Math]::Floor(($scrollAvailableWidth+10)/$scrollCellWidth))
    $scrollRows=[int][Math]::Ceiling($maxItems/[double]$scrollColumns)
    $scrollContentHeight=10+($scrollRows*$scrollCardHeight)+([Math]::Max(0,$scrollRows-1)*13)+10
    $flow.AutoScrollMinSize=New-Object System.Drawing.Size(1,[int]$scrollContentHeight)
    $flow.HorizontalScroll.Enabled=$false
    $flow.HorizontalScroll.Visible=$false

    $timer=New-Object System.Windows.Forms.Timer
    # 70 мс вместо 120: дуга крутится плавно, а не рывками. Тик по-прежнему
    # заодно опрашивает завершившиеся curl-процессы.
    $timer.Interval=70
    $timer.Add_Tick({
        try {
            foreach($client in @($dialogState.Clients)){
                if($null -eq $client){continue}
                try {
                    if(-not $client.DoneHandled -and $client.HasExited){
                        $client.DoneHandled=$true
                        $target=$client.TargetPictureBox
                        $sp=$client.TargetSpinner
                        $file=[string]$client.TempFile
                        $ok=$false
                        try {
                            if($client.ExitCode -eq 0 -and (Test-Path -LiteralPath $file)){
                                $fi=Get-Item -LiteralPath $file -ErrorAction SilentlyContinue
                                if($fi -and $fi.Length -ge 128){
                                    $bytes=[System.IO.File]::ReadAllBytes($file)
                                    $ms=New-Object System.IO.MemoryStream(,$bytes)
                                    $img=[System.Drawing.Image]::FromStream($ms)
                                    if($target.Image){try{$target.Image.Dispose()}catch{}}
                                    $target.Image=$img
                                    $target | Add-Member -NotePropertyName ImageStream -NotePropertyValue $ms -Force
                                    if($sp){Set-CoverSpinnerState $sp 'done'}
                                    $ok=$true
                                }
                            }
                        } catch { $ok=$false }
                        if(-not $ok -and $sp){Set-CoverSpinnerState $sp 'failed'}
                        try{Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue}catch{}
                        try{$client.Dispose()}catch{}
                    } elseif(-not $client.DoneHandled){
                        # Миниатюра ещё грузится — крутим её спиннер.
                        Step-CoverSpinner $client.TargetSpinner
                    }
                } catch {}
            }
        } catch {}
    })
    $dlg.Add_FormClosed({
        try { $titleSearchTimer.Stop(); $titleSearchTimer.Dispose() } catch {}
    })

    $dlg.Add_Shown({$timer.Start()})
    $dlg.Add_FormClosed({
        $dialogState.Closed=$true
        try{$timer.Stop();$timer.Dispose()}catch{}
        foreach($client in @($dialogState.Clients)){
            try{if($client -is [System.Diagnostics.Process]){if(-not $client.HasExited){$client.Kill()};$client.WaitForExit(500)}}catch{}
            try{Remove-Item -LiteralPath ([string]$client.TempFile) -Force -ErrorAction SilentlyContinue}catch{}
            try{$client.Dispose()}catch{}
        }
    })

    $btnClose=New-Object System.Windows.Forms.Button
    $btnClose.Text=(T 'set_cancel')
    $btnClose.Location=New-Object System.Drawing.Point(875,635)
    $btnClose.Size=New-Object System.Drawing.Size(120,32)
    $btnClose.Anchor='Bottom,Right'
    $btnClose.Add_Click({$dlg.DialogResult=[System.Windows.Forms.DialogResult]::Cancel;$dlg.Close()})
    $dlg.Controls.Add($btnClose)
    $dlg.CancelButton=$btnClose

    # Точный размер окна — по факту нижнего края кнопки «Отмена» (плюс
    # небольшой отступ), а не по произвольно подобранным числам. Это и убирает
    # пустую тёмную полосу снизу, и не зависит от масштабирования экрана,
    # потому что ClientSize и Location/Size дочерних элементов масштабируются
    # WinForms согласованно.
    $dlg.ClientSize=New-Object System.Drawing.Size(1024, ($btnClose.Bottom+15))

    $dlg.ShowDialog($owner)|Out-Null
    return $dialogState.Result
}

# ===================== ПРЯМОЕ ПРИМЕНЕНИЕ СВЕЖЕСКАЧАННЫХ ОБЛОЖЕК =====================
# Используется автоматическим потоком "Добавить выбранные игры в Steam":
# копирует обложки НАПРЯМУЮ из temp-папки в config\grid.
function Copy-TempCoversDirectlyToGrid ($shortcutId) {
    $steamPathProperty = Get-ConfiguredSteamExePath
    $steamPath = Get-ConfiguredSteamInstallPath
    $userDataPath = Get-ConfiguredSteamUserDataPath
    if (-not (Test-Path $userDataPath)) { return $false }

    Get-ConfiguredSteamProfileDirectories | ForEach-Object {
        $cacheDir = Join-Path $_.FullName "config\librarycache"
        if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
        $jsonContent = "{`"appid`":$shortcutId,`"Count`":1}"
        $jsonContent | Out-File (Join-Path $cacheDir ($shortcutId + ".json")) -Encoding ascii -Force

        $gridDir = Join-Path $_.FullName "config\grid"
        if (-not (Test-Path $gridDir)) { New-Item -ItemType Directory -Path $gridDir | Out-Null }

        if (Test-Path (Join-Path $global:tempCovers "temp_p.jpg")) { Copy-Item (Join-Path $global:tempCovers "temp_p.jpg") (Join-Path $gridDir ($shortcutId + "p.jpg")) -Force }
        if (Test-Path (Join-Path $global:tempCovers "temp_hero.jpg")) { Copy-Item (Join-Path $global:tempCovers "temp_hero.jpg") (Join-Path $gridDir ($shortcutId + "_hero.jpg")) -Force }
        if (Test-Path (Join-Path $global:tempCovers "temp_logo.png")) { Copy-Item (Join-Path $global:tempCovers "temp_logo.png") (Join-Path $gridDir ($shortcutId + "_logo.png")) -Force }
        if (Test-Path (Join-Path $global:tempCovers "temp_header.jpg")) { Copy-Item (Join-Path $global:tempCovers "temp_header.jpg") (Join-Path $gridDir ($shortcutId + ".jpg")) -Force }
    }

    if (Test-Path $global:tempCovers) { Remove-Item $global:tempCovers -Recurse -Force -ErrorAction SilentlyContinue }
    if (-not (Test-Path $global:tempCovers)) { New-Item -ItemType Directory -Path $global:tempCovers | Out-Null }
    return $true
}


# ===================== НОВАЯ КАРТОЧКА ИГРЫ =====================
function Get-EditorExecutableCandidates ($gamePath) {
    if ([string]::IsNullOrWhiteSpace($gamePath) -or -not (Test-Path $gamePath)) { return @() }
    $junkPattern = '(?i)unins00|\buninstall(er)?\b|unitycrashhandler|crashpad|crashreportclient|crashreporter|crs-handler|crs-uploader|unrealcefsubprocess|\bcefsubprocess\b|\bcefsharp\b|browsersubprocess|driverversionchecker|layerschecker|battleye|easyanticheat|\beac\b|vc_?redist|_?commonredist|\bdotnetfx\b|\bdxsetup\b|\bdirectx\b.*setup|\bprereqsetup\b|physxsetup|vcredist|vulkanrt|\bautorun\b|\bupdater\b|\bpatcher\b|installer\.exe$|_original|_crack|\\Support\\|\\runtimes\\|\\(config|settings|options|cfg)\.exe$'
    $all = @(Get-ChildItem -Path $gamePath -Filter '*.exe' -File -Recurse -ErrorAction SilentlyContinue)
    $clean = @($all | Where-Object { $_.FullName -notmatch $junkPattern })
    if ($clean.Count -eq 0) { $clean = $all }
    $root = @($clean | Where-Object { $_.DirectoryName.TrimEnd('\') -eq $gamePath.TrimEnd('\') })
    $ordered = if ($root.Count -gt 0) { $root } else { $clean }
    # БАГ-ФИКС: раньше сортировка учитывала только "лежит ли exe в корне папки
    # игры", а среди файлов одного уровня вложенности порядок был чисто
    # алфавитным. Из-за этого, например, для Baldur's Gate 3 (ни bin\bg3.exe,
    # ни Launcher\LariLauncher.exe не лежат в корне) файлы просто сортировались
    # по имени, и совпадение, что "b" < "L", было единственной причиной, почему
    # прямой exe вообще оказывался первым — при другом имени лаунчера или игры
    # первым мог оказаться именно лаунчер. Добавлен явный признак "похоже на
    # лаунчер" (по имени файла/папки), который ставится ниже прямых exe вне
    # зависимости от алфавита — это и есть то самое "прямой запуск
    # предпочтительнее лаунчера", которое должно было работать всегда.
    $launcherLikePattern = '(?i)launcher'
    return @($ordered | Sort-Object `
        @{Expression={ if ($_.DirectoryName.TrimEnd('\') -eq $gamePath.TrimEnd('\')) { 0 } else { 1 } }}, `
        @{Expression={ if ($_.FullName -match $launcherLikePattern) { 1 } else { 0 } }}, `
        Name)
}


# ===================== ИСТОЧНИК МИНИАТЮР =====================
# Ресурсы интерфейса встроены непосредственно в EXE/скрипт как Base64.
# Отдельная папка assets рядом с программой больше не требуется.
$global:embeddedSteamGridSourcePng = "iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAYAAACM/rhtAAACgElEQVR4nO2XP2gUQRSHvzc7s3eXnCSaYFDQQkSDlZg0VqKIIFgFEoLYGlMELbRIJxYiNhKwSiVoeQgKlmmEKAoXBZsgWmihiGjUxFxyu7fzLC5/MP8UwuZS7Fct7Bt+3+48Zt9CRkZGRsa2Rta53kq0Qbn/R9do2XWNlt169y3A0QvD11y+eDmqTMe+lrj0X6V6Y51J4tr7iUvdpzaqtADiaRNj9tmwiXzHbvA+bUHEWJJavOPMrScDIsgvV7n/4mrf3JqCmCBOoqoG+WLUur8z9HHEYkuqpiWriJhWm28eFRH08/tHwBwnrtuu83vlwNiYL5VKia1LqCAioJJEVQGl/VA3oAQujxhJqZVVxQQxQHtn9+vuniuBa+bsyBF5NbFQYVetEUEQbJgDMUx/ekcSVUEMKVgKENZjZU/YXOTHh8mLJ4bvva1Fs+Vnd4bGVwsuPZtijPB18iXV6SkkcGkI/p3pveaKLYOFXXuIKzMjwPqCi9hcE74QIYFNXRBEvK9Vot8/rYr+grW2eAWqHvUexG+BIAAWkVCUAMBsReJmyAQ3iwFQJAEihFqDfVZR/9QpLa5QDDFBqOpVxDRqslmFBQgCHkZzMx8LrR2HXb446ONqo72WsAATD26OA+Pn7j4/hq/1qNcEaAMFVUfjZsWFc7C3N+jaedrMfKu+eXrjZEf/45mOwq7iF2NAAouqV6nLpm8koqgqYnRZsFRKJiglizVJ9cd0ZSoZDIzR2vzsbVdobtXUR7A66pOccSHMe7csuIJS3/45YBTg+NBIv8nlD2oSe9X0jyURiX0cOxG+b1g4UFY3UNZ1R/Gt4n+aP61h8F+x2/tnKiMjIyOjzh8Y+O3gszUY9QAAAABJRU5ErkJggg=="
$global:embeddedNoCoverSteamJpg = "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"
$global:embeddedNoCoverSteamGridJpg = "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"

function Get-EmbeddedAssetBytes([string]$name) {
    try {
        $b64 = switch ($name) {
            'steamgrid_source.png'  { $global:embeddedSteamGridSourcePng }
            'no_cover_steam.jpg'   { $global:embeddedNoCoverSteamJpg }
            'no_cover_steamgrid.jpg' { $global:embeddedNoCoverSteamGridJpg }
            default { $null }
        }
        if ([string]::IsNullOrWhiteSpace([string]$b64)) { return $null }
        return [System.Convert]::FromBase64String($b64)
    } catch { return $null }
}

function Get-EditorMissingPlaceholderBitmap([string]$source) {
    try {
        $name = if ($source -eq 'Steam') { 'no_cover_steam.jpg' } else { 'no_cover_steamgrid.jpg' }
        $bytes = Get-EmbeddedAssetBytes $name
        if ($null -eq $bytes) { return $null }
        $ms = New-Object System.IO.MemoryStream(,$bytes)
        try {
            $img = [System.Drawing.Image]::FromStream($ms)
            try { return New-Object System.Drawing.Bitmap($img) } finally { $img.Dispose() }
        } finally { $ms.Dispose() }
    } catch { return $null }
}

function Get-SteamSourceIconBitmap {
    try {
        $steamExe = [string](Get-ConfiguredSteamExePath)
        if ([string]::IsNullOrWhiteSpace($steamExe) -or -not (Test-Path $steamExe)) {
            $steamExe = "C:\Program Files (x86)\Steam\steam.exe"
        }
        if (Test-Path $steamExe) {
            $ico = [System.Drawing.Icon]::ExtractAssociatedIcon($steamExe)
            if ($null -ne $ico) {
                # Нормализуем и уменьшаем иконку до 22x22 с прозрачным полем,
                # чтобы исходная иконка Steam никогда не обрезалась.
                $bmp = New-Object System.Drawing.Bitmap 22,22
                $g = [System.Drawing.Graphics]::FromImage($bmp)
                try {
                    $g.Clear([System.Drawing.Color]::Transparent)
                    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                    $icoBmp = $ico.ToBitmap()
                    try {
                        $g.DrawImage($icoBmp, 2, 2, 18, 18)
                    } finally {
                        $icoBmp.Dispose()
                    }
                } finally {
                    $g.Dispose()
                    $ico.Dispose()
                }
                return $bmp
            }
        }
    } catch {}

    # Резервный узнаваемый Steam-знак, если steam.exe ещё не найден.
    try {
        $bmp = New-Object System.Drawing.Bitmap 28,28
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        try {
            $g.Clear([System.Drawing.Color]::Transparent)
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 3)
            $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(45,118,180))
            $g.FillEllipse($brush, 1, 1, 26, 26)
            $g.DrawEllipse($pen, 1, 1, 26, 26)
            $g.DrawEllipse($pen, 14, 5, 8, 8)
            $g.DrawLine($pen, 14, 12, 9, 17)
            $g.DrawLine($pen, 9, 17, 6, 15)
            $pen.Dispose(); $brush.Dispose()
        } finally { $g.Dispose() }
        return $bmp
    } catch { return $null }
}

function Get-SteamGridDbSourceIconBitmap {
    try {
        $bytes = Get-EmbeddedAssetBytes 'steamgrid_source.png'
        if ($null -eq $bytes) { return $null }
        $ms = New-Object System.IO.MemoryStream(,$bytes)
        try {
            $img = [System.Drawing.Image]::FromStream($ms)
            try {
                # Приводим SGDB-иконку к тому же безопасному 22x22 формату,
                # чтобы она полностью помещалась в PictureBox.
                $bmp = New-Object System.Drawing.Bitmap 22,22
                $g = [System.Drawing.Graphics]::FromImage($bmp)
                try {
                    $g.Clear([System.Drawing.Color]::Transparent)
                    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                    $srcW = [int]$img.Width
                    $srcH = [int]$img.Height
                    $scale = [Math]::Min(18.0 / [Math]::Max(1,$srcW), 18.0 / [Math]::Max(1,$srcH))
                    $dstW = [int][Math]::Round($srcW * $scale)
                    $dstH = [int][Math]::Round($srcH * $scale)
                    $dstX = [int][Math]::Round((22 - $dstW) / 2.0)
                    $dstY = [int][Math]::Round((22 - $dstH) / 2.0)
                    $g.DrawImage($img, $dstX, $dstY, $dstW, $dstH)
                } finally { $g.Dispose() }
                return $bmp
            } finally { $img.Dispose() }
        } finally { $ms.Dispose() }
    } catch { return $null }
}

# Иконка SGDB для заголовков окон (маленький значок в левом углу заголовка).
# Собирается один раз из встроенного steamgrid_source.png (та же картинка, что
# помечает источник обложек) и кэшируется на весь сеанс.
$global:sgdbFormIcon = $null
function Get-SteamGridDbFormIcon {
    if ($null -ne $global:sgdbFormIcon) { return $global:sgdbFormIcon }
    try {
        $bytes = Get-EmbeddedAssetBytes 'steamgrid_source.png'
        if ($null -eq $bytes) { return $null }
        $ms = New-Object System.IO.MemoryStream(,$bytes)
        try {
            $img = [System.Drawing.Image]::FromStream($ms)
            try {
                # 32x32 с прозрачным полем: Windows сама уменьшит до размера
                # заголовка (16 px при 100% масштабе, больше при 125-200%).
                $bmp = New-Object System.Drawing.Bitmap 32,32
                $g = [System.Drawing.Graphics]::FromImage($bmp)
                try {
                    $g.Clear([System.Drawing.Color]::Transparent)
                    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                    $scale = [Math]::Min(30.0 / [Math]::Max(1,[int]$img.Width), 30.0 / [Math]::Max(1,[int]$img.Height))
                    $dstW = [int][Math]::Round($img.Width * $scale)
                    $dstH = [int][Math]::Round($img.Height * $scale)
                    $g.DrawImage($img, [int][Math]::Round((32 - $dstW) / 2.0), [int][Math]::Round((32 - $dstH) / 2.0), $dstW, $dstH)
                } finally { $g.Dispose() }
                try { $global:sgdbFormIcon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon()) } finally { $bmp.Dispose() }
            } finally { $img.Dispose() }
        } finally { $ms.Dispose() }
    } catch { $global:sgdbFormIcon = $null }
    return $global:sgdbFormIcon
}

# Значки для кнопок переключения источника поиска (Steam / SGDB) в карточке игры.
# Берём те же 22x22 картинки, что помечают источник обложек, обрезаем прозрачное
# поле и приводим к 16x16. Возвращаем пару: обычный значок и приглушённый (для
# неактивного источника и заблокированной кнопки SGDB).
function New-SourceButtonIconPair ($sourceBmp) {
    if ($null -eq $sourceBmp) { return $null }
    try {
        $bright = New-Object System.Drawing.Bitmap 16,16
        $g = [System.Drawing.Graphics]::FromImage($bright)
        try {
            $g.Clear([System.Drawing.Color]::Transparent)
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $dest = New-Object System.Drawing.Rectangle 0,0,16,16
            $g.DrawImage($sourceBmp, $dest, 2, 2, 18, 18, [System.Drawing.GraphicsUnit]::Pixel)
        } finally { $g.Dispose() }

        $dim = New-Object System.Drawing.Bitmap 16,16
        $g2 = [System.Drawing.Graphics]::FromImage($dim)
        try {
            $g2.Clear([System.Drawing.Color]::Transparent)
            $cm = New-Object System.Drawing.Imaging.ColorMatrix
            $cm.Matrix33 = 0.5
            $ia = New-Object System.Drawing.Imaging.ImageAttributes
            $ia.SetColorMatrix($cm)
            $dest2 = New-Object System.Drawing.Rectangle 0,0,16,16
            $g2.DrawImage($bright, $dest2, 0, 0, 16, 16, [System.Drawing.GraphicsUnit]::Pixel, $ia)
            $ia.Dispose()
        } finally { $g2.Dispose() }
        return [PSCustomObject]@{ Bright = $bright; Dim = $dim }
    } catch { return $null }
}

# ===================== МЕТАДАННЫЕ ОБ ИСТОЧНИКЕ ОБЛОЖЕК =====================
# Один JSON-файл на shortcutId в $global:coverSourcesDir, например "12345678.json":
# {"p":"Steam","header":"SteamGridDB","hero":"Steam","logo":"SteamGridDB"}
# Без этих файлов при повторном открытии карточки уже сохранённой игры узнать,
# откуда взялась каждая конкретная миниатюра, неоткуда — сам Steam это не хранит.

function Get-CoverSourcesMetadataPath([string]$shortcutId) {
    if ([string]::IsNullOrWhiteSpace($shortcutId)) { return $null }
    return (Join-Path $global:coverSourcesDir ($shortcutId + ".json"))
}

function Get-CoverSourcesMetadata([string]$shortcutId) {
    try {
        $path = Get-CoverSourcesMetadataPath $shortcutId
        if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path $path)) { return $null }
        $raw = Get-Content -LiteralPath $path -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        return ($raw | ConvertFrom-Json -ErrorAction Stop)
    } catch { return $null }
}

# $slots — та же коллекция слотов карточки (Vertical/Horizontal/Hero/Logo),
# что используется в редакторе. Пишем текущий .Source каждого слота на диск,
# чтобы при следующем открытии карточки значки источников не терялись.
function Save-CoverSourcesMetadata([string]$shortcutId, $slots, [string]$coverLang = '') {
    try {
        if ([string]::IsNullOrWhiteSpace($shortcutId) -or $null -eq $slots) { return $false }
        if (-not (Test-Path $global:coverSourcesDir)) { New-Item -ItemType Directory -Path $global:coverSourcesDir -Force | Out-Null }
        $path = Get-CoverSourcesMetadataPath $shortcutId
        if ([string]::IsNullOrWhiteSpace($path)) { return $false }

        $resolve = { param($slot) $s = try { [string]$slot.Source } catch { $null }; if ([string]::IsNullOrWhiteSpace($s)) { 'Steam' } else { $s } }
        $data = [ordered]@{
            p      = (& $resolve $slots.Vertical)
            header = (& $resolve $slots.Horizontal)
            hero   = (& $resolve $slots.Hero)
            logo   = (& $resolve $slots.Logo)
        }
        # Регион (язык) Steam-обложек — чтобы при повторном открытии карточки кнопка
        # региона показывала тот, на котором обложки были сохранены.
        if (-not [string]::IsNullOrWhiteSpace($coverLang)) { $data['lang'] = $coverLang }
        ($data | ConvertTo-Json -Compress) | Out-File -LiteralPath $path -Encoding utf8 -Force
        return $true
    } catch { return $false }
}

# Удаляет устаревший файл метаданных, если у ярлыка при сохранении сменился
# shortcutId (например, из-за изменения имени или пути к EXE — оба участвуют
# в CRC-32, формирующем этот ID). Иначе рядом накапливался бы мусор от ID,
# которого в Steam уже не существует.
function Remove-CoverSourcesMetadata([string]$shortcutId) {
    try {
        $path = Get-CoverSourcesMetadataPath $shortcutId
        if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path $path)) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
    } catch {}
}

# Удаляет из $global:coverSourcesDir все файлы метаданных, чей ShortcutId
# (имя файла без .json) отсутствует в $liveShortcutIds — то есть игра, которой
# принадлежали эти обложки, была удалена из библиотеки Steam (shortcuts.vdf).
# $liveShortcutIds — хэш-таблица вида @{ "12345678" = $true; ... }, собранная
# при свежем чтении shortcuts.vdf в Refresh-Panels.
function Remove-OrphanedCoverSourcesMetadata($liveShortcutIds) {
    try {
        if (-not (Test-Path $global:coverSourcesDir)) { return }
        Get-ChildItem -Path $global:coverSourcesDir -Filter "*.json" -File -ErrorAction SilentlyContinue | ForEach-Object {
            $id = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
            if ([string]::IsNullOrWhiteSpace($id)) { return }
            if ($liveShortcutIds -eq $null -or -not $liveShortcutIds.ContainsKey($id)) {
                Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {}
}

function Set-EditorSourceBadge($slot, [string]$source) {
    try {
        if ($null -eq $slot -or $null -eq $slot.SourceBadge) { return }
        $slot.Source = [string]$source

        if ([string]::IsNullOrWhiteSpace($source)) {
            $slot.SourceBadge.Visible = $false
            try { $slot.SourceBadge.Image.Dispose() } catch {}
            $slot.SourceBadge.Image = $null
            $slot.SourceBadge.Tag = $null
            return
        }

        $bmp = if ($source -eq 'Steam') { Get-SteamSourceIconBitmap } else { Get-SteamGridDbSourceIconBitmap }
        if ($null -eq $bmp) {
            $slot.SourceBadge.Visible = $false
            return
        }

        try { if ($null -ne $slot.SourceBadge.Image) { $slot.SourceBadge.Image.Dispose() } } catch {}
        $slot.SourceBadge.Image = $bmp
        $slot.SourceBadge.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
        $slot.SourceBadge.Visible = $true
        $slot.SourceBadge.BringToFront()
        try {
            if ($null -eq $slot.SourceBadge.Tag -or $slot.SourceBadge.Tag -isnot [System.Windows.Forms.ToolTip]) {
                $tt = New-Object System.Windows.Forms.ToolTip
                $slot.SourceBadge.Tag = $tt
            }
            $tipText = if ($source -eq 'Steam') { (T 'src_tip_steam') } else { (T 'src_tip_sgdb') }
            $slot.SourceBadge.Tag.SetToolTip($slot.SourceBadge, $tipText)
        } catch {}
    } catch {}
}

function Set-EditorMissingState($slot, [bool]$missing) {
    if ($null -eq $slot) { return }
    try { $slot.PendingMissing = $missing } catch {}
    try {
        if (-not $missing) {
            # Миниатюра есть — убираем заглушку и спиннер.
            Set-EditorSlotLoading $slot $false
            $slot.Missing.Visible = $false
            $slot.Picture.Visible = $true
            return
        }

        # Источник известен из текущей операции загрузки.
        $expected = ''
        try { $expected = [string]$slot.ExpectedSource } catch {}
        if ([string]::IsNullOrWhiteSpace($expected)) {
            try { $expected = [string]$slot.Source } catch {}
        }
        if ([string]::IsNullOrWhiteSpace($expected)) { $expected = 'Steam' }

        # При отсутствии обложки используем красивую заглушку именно этого источника,
        # а не старый красный крест.
        try {
            $placeholder = Get-EditorMissingPlaceholderBitmap $expected
            if ($null -ne $placeholder) {
                if ($null -ne $slot.Missing.Image) { $slot.Missing.Image.Dispose() }
                $slot.Missing.Image = $placeholder
            }
        } catch {}

        # Пока загрузка идёт — только анимация. Значок источника и заглушка
        # появляются после завершения попытки загрузки.
        if ($slot.IsLoading) {
            $slot.Missing.Visible = $false
            $slot.Picture.Visible = $true
            try { if ($null -ne $slot.Loading) { $slot.Loading.BringToFront() } } catch {}
            return
        }

        try { Set-EditorSourceBadge $slot $expected } catch {}
        $slot.Missing.Visible = $true
        $slot.Picture.Visible = $false
    } catch {}
}

function Set-EditorPreviewFile($slot, $filePath) {
    try {
        if ($slot.Stream -ne $null) { $slot.Stream.Dispose(); $slot.Stream = $null }
        if ($slot.Picture.Image -ne $null) { $slot.Picture.Image.Dispose(); $slot.Picture.Image = $null }
    } catch {}
    if ([string]::IsNullOrWhiteSpace($filePath) -or -not (Test-Path $filePath) -or (Get-Item $filePath -ErrorAction SilentlyContinue).Length -lt 512) {
        Set-EditorMissingState $slot $true
        return $false
    }
    try {
        $bytes = [System.IO.File]::ReadAllBytes($filePath)
        $ms = New-Object System.IO.MemoryStream(,$bytes)
        $img = [System.Drawing.Image]::FromStream($ms)
        $slot.Stream = $ms
        $slot.Picture.Image = New-Object System.Drawing.Bitmap($img)
        $img.Dispose()
        Set-EditorMissingState $slot $false
        return $true
    } catch {
        Set-EditorMissingState $slot $true
        return $false
    }
}

function New-EditorCoverSlot($parent, [string]$title, [int]$x, [int]$y, [int]$w, [int]$h) {
    $group = New-Object System.Windows.Forms.Panel
    $group.Location = New-Object System.Drawing.Point($x, $y)
    $group.Size = New-Object System.Drawing.Size($w, $h)
    $group.BackColor = $steamUi.Panel2
    $group.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $parent.Controls.Add($group)

    $caption = New-Object System.Windows.Forms.Label
    $caption.Text = $title
    $caption.Location = New-Object System.Drawing.Point(10, 8)
    $caption.Size = New-Object System.Drawing.Size(([int]$w - 52), 22)
    $caption.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
    $caption.ForeColor = $steamUi.Text
    $group.Controls.Add($caption)

    $pb = New-Object System.Windows.Forms.PictureBox
    $pb.Location = New-Object System.Drawing.Point(10, 35)
    $pb.Size = New-Object System.Drawing.Size(([int]$w - 20), ([int]$h - 45))
    $pb.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    $pb.BackColor = $steamUi.Input
    $group.Controls.Add($pb)

    $missing = New-Object System.Windows.Forms.PictureBox
    $missing.Location = New-Object System.Drawing.Point(10, 35)
    $missing.Size = New-Object System.Drawing.Size(([int]$w - 20), ([int]$h - 45))
    $missing.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    $missing.BackColor = $steamUi.Input
    $missing.Visible = $false
    $group.Controls.Add($missing)
    $missing.BringToFront()
    # БАГ-ФИКС: раньше крестик был виден сразу при открытии карточки игры —
    # ещё до того, как хоть что-то начали грузить. Из-за этого пользователь
    # видел последовательность "красный крест → анимация → миниатюра".
    # Теперь слот стартует пустым, а крест показывается ТОЛЬКО когда загрузка
    # закончилась и обложки в источнике действительно нет.
    $missing.Visible = $false

    # Маленький значок источника располагается В СТРОКЕ ЗАГОЛОВКА,
    # справа от названия миниатюры, а не поверх самой картинки.
    $sourceBadge = New-Object System.Windows.Forms.PictureBox
    $sourceBadge.Size = New-Object System.Drawing.Size(22,22)
    $sourceBadge.Location = New-Object System.Drawing.Point(([int]$w - 32), 7)
    $sourceBadge.BackColor = [System.Drawing.Color]::Transparent
    $sourceBadge.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    $sourceBadge.Visible = $false
    $sourceBadge.Cursor = [System.Windows.Forms.Cursors]::Default
    $group.Controls.Add($sourceBadge)
    $sourceBadge.BringToFront()

    $pb.Cursor = [System.Windows.Forms.Cursors]::Hand
    return [PSCustomObject]@{
        Panel=$group
        Picture=$pb
        Missing=$missing
        Stream=$null
        Loading=$null
        SourceBadge=$sourceBadge
        Source=$null
        ExpectedSource=$null
        # IsLoading — идёт ли прямо сейчас загрузка ИМЕННО этой миниатюры.
        # PendingMissing — "обложки нет", отложенный до конца загрузки вердикт.
        IsLoading=$false
        PendingMissing=$false
        SgdbItems=@()
        SgdbSelectedUrl=$null
    }
}



function Set-EditorSlotLoading($slot, [bool]$loading) {
    try {
        if ($null -eq $slot) { return }
        $slot.IsLoading = $loading
        if ($loading) {
            # Крест на время загрузки всегда прячем.
            try { $slot.Missing.Visible = $false; $slot.Picture.Visible = $true } catch {}
            if ($null -eq $slot.Loading) {
                $spin = New-CoverSpinner $slot.Picture $steamUi.Accent 56
                $spin.Dock = 'None'
                $spin.Location = $slot.Picture.Location
                $spin.Size = $slot.Picture.Size
                $spin.BackColor = $steamUi.Input
                $slot.Panel.Controls.Add($spin)
                $slot.Loading = $spin
            }
            Set-CoverSpinnerState $slot.Loading 'loading'
            $slot.Loading.BringToFront()
        } elseif ($null -ne $slot.Loading) {
            Set-CoverSpinnerState $slot.Loading 'done'
        }
    } catch {}
}

function Start-EditorLoading($slots, $form) {
    # Пока карточка грузит обложки — качаем так, чтобы UI не замирал
    # и анимация реально крутилась (см. Invoke-UiPumpingDownload).
    $global:uiPumpDuringDownload = $true
    foreach($slot in $slots.Values) {
        Set-EditorSourceBadge $slot $null
        Set-EditorSlotLoading $slot $true
    }
    try {
        if ($null -ne $form) {
            if ($null -eq $form.Tag -or $null -eq $form.Tag.EditorLoadTimer) {
                $timer = New-Object System.Windows.Forms.Timer
                $timer.Interval = 70
                $timer.Tag = [PSCustomObject]@{Frame=0;Slots=$slots}
                $timer.Add_Tick({
                    try {
                        # БАГ-ФИКС: раньше здесь было $_.Sender — у PowerShell в
                        # обработчике события отправитель лежит в $this, а $_ —
                        # это EventArgs. Обращение к .Sender падало, исключение
                        # глушил catch, и анимация в карточке игры не работала
                        # вообще: символ так и висел неподвижно.
                        $t = $this
                        foreach($slot in $t.Tag.Slots.Values) {
                            if ($null -ne $slot.Loading) { Step-CoverSpinner $slot.Loading }
                        }
                    } catch {}
                })
                $form.Tag = [PSCustomObject]@{EditorLoadTimer=$timer;EditorSlots=$slots}
            }
            $form.Tag.EditorLoadTimer.Start()
        }
    } catch {}
}

function Stop-EditorLoading($slots, $form) {
    $global:uiPumpDuringDownload = $false
    foreach($slot in $slots.Values) {
        Set-EditorSlotLoading $slot $false
        # Загрузка закончилась — теперь показываем source-specific заглушку,
        # если обложки в источнике действительно не оказалось.
        Set-EditorMissingState $slot ([bool]$slot.PendingMissing)
    }
    try {
        if ($null -ne $form -and $null -ne $form.Tag -and $null -ne $form.Tag.EditorLoadTimer) {
            $form.Tag.EditorLoadTimer.Stop()
        }
    } catch {}
}


# ===================== КНОПКА РЕГИОНА ОБЛОЖЕК В КАРТОЧКЕ =====================
# Кнопка (Name = 'EditorCoverLangButton') показывает регион (язык) Steam-обложек,
# которые сейчас загружены в карточку. Состояние лежит в её .Tag (Lang + ToolTip),
# чтобы глобальные функции загрузки могли обновлять её, не зная про локальные
# переменные карточки.
function Set-EditorCoverLangButton($btn, [string]$steamLang) {
    try {
        if ($null -eq $btn) { return }
        if ([string]::IsNullOrWhiteSpace($steamLang)) { $steamLang = 'english' }
        $info = Get-SteamLanguageInfo $steamLang
        $btn.Text = [string]$info.Short
        $btn.Tag.Lang = [string]$info.Steam
        $btn.Tag.Tip.SetToolTip($btn, (T 'covlang_tip' @([string]$info.Name)))
    } catch {}
}

# Перезагружает Steam-обложки карточки на выбранном языке. Заменяются только
# те миниатюры, что сейчас из Steam (или пустые): выбранное вручную из SteamGridDB
# не трогаем. Файл заменяется, только если новый скачался, — иначе остаётся
# текущая картинка. Возвращает, сколько миниатюр обновлено.
function Reload-EditorSteamCoversForLanguage($appId, $slots, $statusLabel, [string]$lang) {
    $langName = [string](Get-SteamLanguageInfo $lang).Name
    $form = $null
    try { $form = $statusLabel.FindForm() } catch {}

    $defs = @(
        @{ Name='Vertical';   File='temp_p.jpg';      Prop='Capsule'; Legacy='library_600x900.jpg' },
        @{ Name='Horizontal'; File='temp_header.jpg'; Prop='Header';  Legacy='header.jpg' },
        @{ Name='Hero';       File='temp_hero.jpg';   Prop='Hero';    Legacy='library_hero.jpg' },
        @{ Name='Logo';       File='temp_logo.png';   Prop='Logo';    Legacy='logo.png' }
    )
    $targets = [ordered]@{}
    $targetDefs = @()
    foreach ($d in $defs) {
        $slot = $slots[[string]$d.Name]
        if ($null -eq $slot) { continue }
        $src = ''
        try { $src = [string]$slot.Source } catch {}
        if ([string]::IsNullOrWhiteSpace($src) -or $src -eq 'Steam') { $targets[[string]$d.Name] = $slot; $targetDefs += $d }
    }
    if ($targetDefs.Count -eq 0) { $statusLabel.Text = (T 'covlang_all_sgdb'); return 0 }

    $statusLabel.Text = (T 'covlang_loading' @($langName))
    Start-EditorLoading $targets $form
    [System.Windows.Forms.Application]::DoEvents()
    $replaced = 0
    try {
        $pics = Get-SteamPicsAssetUrls $appId $lang
        foreach ($d in $targetDefs) {
            $slot = $slots[[string]$d.Name]
            $urls = @()
            if ($pics -ne $null) { $urls = @($pics.([string]$d.Prop)) }
            if ($urls.Count -eq 0 -and $lang -eq 'english') {
                # Английский — стандартная версия: если PICS недоступен, берём прямые ссылки.
                $urls = @(
                    "https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/$appId/$($d.Legacy)",
                    "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/$appId/$($d.Legacy)"
                )
            }
            $dest = Join-Path $global:tempCovers ([string]$d.File)
            $tmp = $dest + '.new'
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            $got = $false
            if ($urls.Count -gt 0) { $got = [bool](Save-FirstWorkingUrl $urls $tmp) }
            if ($got -and (Test-Path -LiteralPath $tmp)) {
                Move-Item -LiteralPath $tmp -Destination $dest -Force
                if (Set-EditorPreviewFile $slot $dest) { $replaced++ }
            }
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
    } catch {
    } finally {
        Stop-EditorLoading $targets $form
        foreach ($d in $targetDefs) {
            $slot = $slots[[string]$d.Name]
            try { if (-not [bool]$slot.PendingMissing) { Set-EditorSourceBadge $slot 'Steam' } } catch {}
        }
    }
    if ($replaced -gt 0) { $statusLabel.Text = (T 'covlang_done' @($langName, $replaced)) }
    else { $statusLabel.Text = (T 'covlang_fail' @($langName)) }
    return [int]$replaced
}

function Load-EditorSteamPreviews($appId, $slots, $statusLabel) {
    foreach($s in $slots.Values){ try { $s.ExpectedSource = 'Steam' } catch {} }
    if ([string]::IsNullOrWhiteSpace([string]$appId) -or [string]$appId -notmatch '^\d+$') {
        foreach($s in $slots.Values){ Set-EditorPreviewFile $s $null | Out-Null }
        $statusLabel.Text = (T 'sl_no_appid')
        return
    }
    $statusLabel.Text = (T 'sl_steam_fetch' @($appId))
    $form = $null
    try { $form = $statusLabel.FindForm() } catch {}
    Start-EditorLoading $slots $form
    [System.Windows.Forms.Application]::DoEvents()
    try {
        # В редакторе Steam — единственный первичный источник. SGDB подключается
        # только отдельной кнопкой; при отсутствии ресурсов показываем
        # встроенную заглушку Steam.
        Download-CoversToTemp $appId $false
        $ok = 0
        if (Set-EditorPreviewFile $slots.Vertical (Join-Path $global:tempCovers 'temp_p.jpg')) { Set-EditorSourceBadge $slots.Vertical 'Steam'; $ok++ }
        if (Set-EditorPreviewFile $slots.Horizontal (Join-Path $global:tempCovers 'temp_header.jpg')) { Set-EditorSourceBadge $slots.Horizontal 'Steam'; $ok++ }
        if (Set-EditorPreviewFile $slots.Hero (Join-Path $global:tempCovers 'temp_hero.jpg')) { Set-EditorSourceBadge $slots.Hero 'Steam'; $ok++ }
        if (Set-EditorPreviewFile $slots.Logo (Join-Path $global:tempCovers 'temp_logo.png')) { Set-EditorSourceBadge $slots.Logo 'Steam'; $ok++ }
        $statusLabel.Text = (T 'sl_steam_found' @($ok))
        # Кнопка региона в карточке — на языке, на котором обложки реально загрузились.
        try {
            $langBtn = $null
            if ($null -ne $form) { $langBtn = @($form.Controls.Find('EditorCoverLangButton', $true))[0] }
            Set-EditorCoverLangButton $langBtn ([string]$script:lastCoversLanguage)
        } catch {}
    } catch {
        foreach($s in $slots.Values){ Set-EditorPreviewFile $s $null | Out-Null }
        $statusLabel.Text = (T 'sl_steam_fail' @([string]$_.Exception.Message))
    } finally {
        Stop-EditorLoading $slots $form
    }
}

function Load-EditorSgdbPreviews($gameName, $steamAppId, $slots, $statusLabel, $onComplete = $null, [int]$sgdbGameId = 0) {
    foreach($s in $slots.Values){ try { $s.ExpectedSource = 'SteamGridDB' } catch {} }
    # FIX 8 — возвращаем проверенную логику из 2.6.4.
    # Ключевой момент: API SteamGridDB вызывается через Invoke-RestMethod,
    # как в старом рабочем picker'е. curl используется только для картинок.
    # Никаких отдельных curl-процессов для autocomplete/API, которые в v3
    # могли зависнуть на этапе "ищу…".
    $completed = $false
    try {
        $apiKey = [string](Ensure-SteamGridDbApiKey)
        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            foreach($s in $slots.Values){ Set-EditorPreviewFile $s $null | Out-Null }
            $statusLabel.Text = (T 'sl_sg_nokey')
            return $false
        }

        $name = [string]$gameName
        $appId = [string]$steamAppId
        if ([string]::IsNullOrWhiteSpace($name) -and [string]::IsNullOrWhiteSpace($appId) -and $sgdbGameId -le 0) {
            $statusLabel.Text = (T 'sl_sg_need_name')
            return $false
        }

        $headers = @{ Authorization = "Bearer $apiKey" }
        $candidate = $null
        $assets = $null
        $form = $null
        try { $form = $statusLabel.FindForm() } catch {}
        Start-EditorLoading $slots $form
        [System.Windows.Forms.Application]::DoEvents()

        # ------------------------------------------------------------
        # 0. Если передан конкретный SGDB Game ID (пользователь выбрал
        # определённый вариант из выпадающего списка названия) — берём
        # обложки ИМЕННО для него, без повторного нечёткого поиска по имени.
        # Без этой ветки повторный поиск по имени для похожих вариантов
        # (разные издания/моды с похожими названиями) почти всегда
        # возвращал один и тот же самый популярный результат — из-за этого
        # выбор другого варианта в списке визуально ничего не менял.
        # ------------------------------------------------------------
        if ($sgdbGameId -gt 0) {
            $statusLabel.Text = (T 'sl_sg_variants' @($name))
            [System.Windows.Forms.Application]::DoEvents()

            $assets = Get-SgdbAssetsForGame $sgdbGameId $headers
            if ($assets -eq $null) {
                $statusLabel.Text = (T 'sl_sg_nocovers' @($name))
                return $false
            }
            $candidate = [PSCustomObject]@{ Id=$sgdbGameId; Name=$name }
        }
        # ------------------------------------------------------------
        # 1. Если App ID указан — НЕ ищем по названию.
        # Используем тот же прямой Steam App ID путь, который уже есть
        # в старом проекте.
        # ------------------------------------------------------------
        elseif ($appId -match '^\d+$') {
            $statusLabel.Text = (T 'sl_sg_by_id' @($appId))
            [System.Windows.Forms.Application]::DoEvents()

            $direct = Get-SteamGridDbAssetsBySteamAppId $appId
            if ($direct -ne $null) {
                $assets = [PSCustomObject]@{
                    GridsVertical   = @($direct.Grids | Where-Object {
                        $w=0;$h=0;try{$w=[int]$_.width;$h=[int]$_.height}catch{}
                        (($w -eq 600 -and $h -eq 900) -or ($w -eq 342 -and $h -eq 482) -or ($w -eq 660 -and $h -eq 930))
                    } | Sort-Object @{Expression={try{[double]$_.score}catch{0}};Descending=$true})
                    GridsHorizontal = @($direct.Grids | Where-Object {
                        $w=0;$h=0;try{$w=[int]$_.width;$h=[int]$_.height}catch{}
                        (($w -eq 920 -and $h -eq 430) -or ($w -eq 460 -and $h -eq 215))
                    } | Sort-Object @{Expression={try{[double]$_.score}catch{0}};Descending=$true})
                    Heroes = @($direct.Heroes | Sort-Object @{Expression={try{[double]$_.score}catch{0}};Descending=$true})
                    Logos  = @($direct.Logos  | Sort-Object @{Expression={try{[double]$_.score}catch{0}};Descending=$true})
                }

                # Fallback по соотношению сторон — как в старой версии.
                if (@($assets.GridsVertical).Count -eq 0) {
                    $assets.GridsVertical = @($direct.Grids | Where-Object {
                        $w=0;$h=0;try{$w=[double]$_.width;$h=[double]$_.height}catch{}
                        $h -gt 0 -and ($w/$h) -ge 0.55 -and ($w/$h) -le 0.78
                    } | Sort-Object @{Expression={try{[double]$_.score}catch{0}};Descending=$true})
                }
                if (@($assets.GridsHorizontal).Count -eq 0) {
                    $assets.GridsHorizontal = @($direct.Grids | Where-Object {
                        $w=0;$h=0;try{$w=[double]$_.width;$h=[double]$_.height}catch{}
                        $h -gt 0 -and ($w/$h) -ge 1.85 -and ($w/$h) -le 2.35
                    } | Sort-Object @{Expression={try{[double]$_.score}catch{0}};Descending=$true})
                }
            }
            if ($assets -eq $null) {
                $statusLabel.Text = (T 'sl_sg_id_none' @($appId))
                return $false
            }
            $candidate = [PSCustomObject]@{ Id=$appId; Name=$name }
        }
        else {
            # ------------------------------------------------------------
            # 2. App ID пуст — повторяем старый поиск по названию:
            # полный запрос + один fallback по первым значимым словам.
            # ------------------------------------------------------------
            $statusLabel.Text = (T 'sl_sg_searching' @($name))
            [System.Windows.Forms.Application]::DoEvents()

            # Та же обработка 401 (переполучить ключ и повторить один раз),
            # что была в рабочем 2.6.4 — теперь через общую обёртку
            # Invoke-SgdbApiRequest, а не продублированной вручную веткой.
            $searchReq = $null
            $searchQueries = @($name)

            $fallbackTokens = @([regex]::Matches($name,'[\p{L}\p{Nd}]+') | ForEach-Object { [string]$_.Value })
            if ($fallbackTokens.Count -gt 1) {
                $fallbackQuery = (($fallbackTokens | Select-Object -First ([Math]::Min(3,[int]$fallbackTokens.Count))) -join ' ')
                if (-not [string]::IsNullOrWhiteSpace($fallbackQuery) -and $fallbackQuery -ne $name) {
                    $searchQueries += $fallbackQuery
                }
            }

            foreach($searchQuery in $searchQueries) {
                if ($searchReq -ne $null -and $searchReq.Success) { break }

                $searchUrl = "https://www.steamgriddb.com/api/v2/search/autocomplete/" + [System.Uri]::EscapeDataString([string]$searchQuery)
                $searchReq = Invoke-SgdbApiRequest $searchUrl $headers 12
                [System.Windows.Forms.Application]::DoEvents()
            }

            if ($searchReq -eq $null -or -not $searchReq.Success) {
                $statusLabel.Text = if($searchReq -ne $null -and $searchReq.ErrorMessage) { (T 'sl_sg_error' @([string]$searchReq.ErrorMessage)) } else { (T 'sl_sg_notfound') }
                return $false
            }

            $candidates = @($searchReq.Data | ForEach-Object {
                if ($null -eq $_) { return }
                $id=0
                try{$id=[int]$_.id}catch{}
                if($id -le 0){return}
                [PSCustomObject]@{
                    Id=$id
                    Name=[string]$_.name
                    Verified=$_.verified
                    Types=@($_.types)
                    MatchScore=Get-SgdbNameScore $name $_
                }
            } | Sort-Object MatchScore -Descending | Select-Object -First 12)

            if ($candidates.Count -eq 0) {
                $statusLabel.Text = (T 'sl_sg_nogames')
                return $false
            }

            # При наличии Steam-типа предпочитаем его — старое поведение.
            $steamMatches = @($candidates | Where-Object { @($_.Types) -contains 'steam' })
            if ($steamMatches.Count -gt 0) {
                $others = @($candidates | Where-Object { $_ -notin $steamMatches })
                $candidates = @($steamMatches + $others)
            }

            $candidate = $candidates[0]
            $statusLabel.Text = (T 'sl_sg_found_fetch' @([string]$candidate.Name))
            [System.Windows.Forms.Application]::DoEvents()

            $assets = Get-SgdbAssetsForGame $candidate.Id $headers
            if ($assets -eq $null) {
                $statusLabel.Text = (T 'sl_sg_nocovers' @([string]$candidate.Name))
                return $false
            }
        }

        # ------------------------------------------------------------
        # 3. Берём самый популярный вариант каждого типа.
        # Это ровно тот же принцип, который использовал старый picker:
        # сначала лучший score, а пользователь потом может заменить вариант
        # уже отдельным chooser'ом при необходимости.
        # ------------------------------------------------------------
        $vertical = @($assets.GridsVertical)
        $horizontal = @($assets.GridsHorizontal)
        $heroes = @($assets.Heroes)
        $logos = @($assets.Logos)

        # Сохраняем ВСЕ варианты, чтобы клик по миниатюре открывал
        # старый проверенный chooser, а не только первый выбранный результат.
        try { $slots.Vertical.SgdbItems = @($vertical) } catch {}
        try { $slots.Horizontal.SgdbItems = @($horizontal) } catch {}
        try { $slots.Hero.SgdbItems = @($heroes) } catch {}
        try { $slots.Logo.SgdbItems = @($logos) } catch {}

        $v = if($vertical.Count -gt 0){[string]$vertical[0].url}else{$null}
        $h = if($horizontal.Count -gt 0){[string]$horizontal[0].url}else{$null}
        $hero = if($heroes.Count -gt 0){[string]$heroes[0].url}else{$null}
        $logo = if($logos.Count -gt 0){[string]$logos[0].url}else{$null}

        $urls = @(
            [PSCustomObject]@{Key='Vertical';Url=$v;File=(Join-Path $global:tempCovers 'temp_p.jpg');Slot=$slots.Vertical},
            [PSCustomObject]@{Key='Horizontal';Url=$h;File=(Join-Path $global:tempCovers 'temp_header.jpg');Slot=$slots.Horizontal},
            [PSCustomObject]@{Key='Hero';Url=$hero;File=(Join-Path $global:tempCovers 'temp_hero.jpg');Slot=$slots.Hero},
            [PSCustomObject]@{Key='Logo';Url=$logo;File=(Join-Path $global:tempCovers 'temp_logo.png');Slot=$slots.Logo}
        )

        # Сначала очищаем старые SGDB-временные картинки, чтобы старый результат
        # никогда не оставался на экране при новом поиске.
        foreach($u in $urls) {
            Remove-Item -LiteralPath $u.File -Force -ErrorAction SilentlyContinue
            Set-EditorPreviewFile $u.Slot $null | Out-Null
        }

        $loaded = 0
        foreach($u in $urls) {
            if ([string]::IsNullOrWhiteSpace([string]$u.Url)) {
                [System.Windows.Forms.Application]::DoEvents()
                continue
            }

            $statusLabel.Text = (T 'sl_sg_loading' @(((T ('slot_' + ([string]$u.Key).ToLower())) -replace '^\d+\.\s*', '')))
            [System.Windows.Forms.Application]::DoEvents()

            # Используем старый проверенный Download-RemoteImage:
            # Invoke-WebRequest -> fallback curl, с таймаутом.
            if (Download-RemoteImage ([string]$u.Url) ([string]$u.File)) {
                if (Set-EditorPreviewFile $u.Slot $u.File) {
                    Set-EditorSourceBadge $u.Slot 'SteamGridDB'
                    $loaded++
                }
            }
            [System.Windows.Forms.Application]::DoEvents()
        }

        if ($loaded -gt 0) {
            $display = if($candidate -and $candidate.Name){[string]$candidate.Name}else{$name}
            $statusLabel.Text = (T 'sl_sg_done' @($loaded, $display))
        }
        else {
            $statusLabel.Text = (T 'sl_sg_imgfail')
        }

        $completed = $true
        return ($loaded -gt 0)
    }
    catch {
        $statusLabel.Text = (T 'sl_sg_error' @([string]$_.Exception.Message))
        return $false
    }
    finally {
        try { Stop-EditorLoading $slots $form } catch {}
        if ($onComplete) {
            try { & $onComplete } catch {}
        }
    }
}


# ===================== РУЧНЫЕ РЕЗЕРВНЫЕ КОПИИ shortcuts.vdf =====================
# Автоматические копии больше не создаются при изменении shortcuts.vdf.
# Пользователь создаёт копию явно из окна "Настройки". Копии лежат рядом
# с программой, чтобы их было легко найти и перенести вместе с Commander.
function Get-SteamShortcutsFiles {
    $files = New-Object System.Collections.ArrayList
    try {
        $userDataPath = Get-ConfiguredSteamUserDataPath
        if (-not (Test-Path $userDataPath)) { return @() }

        foreach ($f in (Get-ChildItem -Path $userDataPath -Filter "shortcuts.vdf" -Recurse -File -ErrorAction SilentlyContinue)) {
            try {
                if ($f.Length -gt 0) { $files.Add($f) }
            } catch {}
        }
    } catch {}
    return @($files)
}

function Get-ManualShortcutBackupFiles {
    try {
        if (-not (Test-Path $global:exeDir)) { return @() }
        $filter = "shortcuts_*.vdf.bak"
        if (-not [string]::IsNullOrWhiteSpace([string]$global:steamUserId) -and [string]$global:steamUserId -match '^\d+$') {
            $filter = "shortcuts_{0}_*.vdf.bak" -f [string]$global:steamUserId
        }
        return @(Get-ChildItem -LiteralPath (Get-BackupFolderPath) -Filter $filter -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending)
    } catch {
        return @()
    }
}

function Resolve-ManualBackupTarget {
    param([System.IO.FileInfo]$BackupFile)
    try {
        if ($BackupFile -eq $null) { return $null }
        $name = [string]$BackupFile.Name
        $m = [System.Text.RegularExpressions.Regex]::Match(
            $name,
            '^shortcuts_(.+)_(\d{4}-\d{2}-\d{2}_\d{2}-\d{2})(?:_\d+)?\.vdf\.bak$'
        )
        if (-not $m.Success) { return $null }
        $accountId = [string]$m.Groups[1].Value

        # Восстановление всегда идёт в профиль, выбранный в настройках.
        $userDataPath = Get-ConfiguredSteamUserDataPath
        if (-not (Test-Path $userDataPath)) {
            try { [System.IO.Directory]::CreateDirectory([string]$userDataPath) | Out-Null } catch {}
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$global:steamUserId) -and [string]$global:steamUserId -match '^\d+$') {
            return (Join-Path (Join-Path $userDataPath "config") "shortcuts.vdf")
        }

        $sourceFiles = @(Get-SteamShortcutsFiles)
        if ($sourceFiles.Count -eq 1) { return [string]$sourceFiles[0].FullName }
        return $null
    } catch {
        return $null
    }
}

function Create-ManualShortcutBackup {
    try {
        $sourceFiles = @(Get-SteamShortcutsFiles)
        if ($sourceFiles.Count -eq 0) {
            return @()
        }

        $backupDir = Get-BackupFolderPath
        [System.IO.Directory]::CreateDirectory([string]$backupDir) | Out-Null
        $stamp = (Get-Date).ToString("yyyy-MM-dd_HH-mm")
        $created = @()

        foreach ($source in $sourceFiles) {
            $accountId = [string]$global:steamUserId
            if ([string]::IsNullOrWhiteSpace($accountId) -or $accountId -notmatch '^\d+$') {
                try { $accountId = [System.IO.Path]::GetFileName($source.Directory.Parent.FullName) } catch {}
            }
            if ([string]::IsNullOrWhiteSpace($accountId) -or $accountId -notmatch '^\d+$') {
                $accountId = "steam"
            }

            # Имя содержит только дату и время до минут. Если несколько копий
            # создаются в одну минуту, добавляем индекс _2, _3, ... вместо секунд,
            # чтобы старые копии никогда не перезаписывались.
            $baseName = "shortcuts_{0}_{1}" -f $accountId, $stamp
            $target = Join-Path $backupDir ($baseName + ".vdf.bak")
            $duplicateIndex = 2
            while (Test-Path -LiteralPath $target) {
                $target = Join-Path $backupDir ("{0}_{1}.vdf.bak" -f $baseName, $duplicateIndex)
                $duplicateIndex++
            }
            try {
                [System.IO.File]::Copy([string]$source.FullName, [string]$target, $false)
                $created += [string]$target
            } catch {}
        }

        if ($created.Count -gt 0) {
            try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
        }
        return @($created)
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            $form,
            ((T 'bk_create_fail') + "`r`n" + [string]$_.Exception.Message),
            (T 'bk_title'),
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return @()
    }
}

function Test-SteamGridDbApiKey([string]$apiKey) {
    # Возвращает результат Get-SgdbKeyCheckResult (Valid, NetworkError, Message
    # и дополнительно Kind/Severity/StatusCode) и обновляет глобальное состояние.
    $check = Get-SgdbKeyCheckResult $apiKey
    $global:steamGridDbApiKeyValid = [bool]$check.Valid
    $global:steamGridDbApiKeyCheck = $check
    return $check
}

function Set-ApiKeyValidationBadge($pictureBox, [string]$state, [string]$tip) {
    try {
        if ($null -eq $pictureBox) { return }
        if ($state -eq 'hidden') {
            $pictureBox.Visible = $false
            return
        }
        # Тот же значок, который уже используется в карточках:
        # зелёная галочка = true, красный ! = false.
        $bmp = Get-ConfidenceBadgeBitmap ($state -eq 'valid')
        try { if ($null -ne $pictureBox.Image) { $pictureBox.Image.Dispose() } } catch {}
        $pictureBox.Image = $bmp
        $pictureBox.Visible = ($null -ne $bmp)
        try {
            if ($null -eq $pictureBox.Tag -or $pictureBox.Tag -isnot [System.Windows.Forms.ToolTip]) {
                $tt = New-Object System.Windows.Forms.ToolTip
                $pictureBox.Tag = $tt
            }
            $pictureBox.Tag.SetToolTip($pictureBox, $tip)
        } catch {}
    } catch {}
}

function Show-ProgramSettingsDialog {
    $originalSteamInstallPath = [string]$global:steamInstallPath
    $originalSteamUserId = [string]$global:steamUserId
    $settingsAccepted = $false

    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = (T 'settings_title')
    $dlg.StartPosition = 'CenterParent'
    $dlg.FormBorderStyle = 'FixedDialog'
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false
    $dlg.ClientSize = New-Object System.Drawing.Size(560, 575)
    $dlg.BackColor = $steamUi.Bg
    $dlg.ForeColor = $steamUi.Text
    $dlg.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $title = New-Object System.Windows.Forms.Label
    $title.Text = (T 'settings_title')
    $title.Location = New-Object System.Drawing.Point(20, 16)
    $title.Size = New-Object System.Drawing.Size(330, 30)
    $title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 16)
    $title.ForeColor = $steamUi.Text
    $dlg.Controls.Add($title)

    # Выбор языка интерфейса — справа от заголовка. Применяется по кнопке «Сохранить».
    $cmbLanguage = New-Object System.Windows.Forms.ComboBox
    $cmbLanguage.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $cmbLanguage.Location = New-Object System.Drawing.Point(390, 20)
    $cmbLanguage.Size = New-Object System.Drawing.Size(150, 26)
    $cmbLanguage.BackColor = $steamUi.Input
    $cmbLanguage.ForeColor = $steamUi.Text
    $cmbLanguage.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    foreach ($langItem in $script:languageList) { [void]$cmbLanguage.Items.Add([string]$langItem.Name) }
    for ($li = 0; $li -lt $script:languageList.Count; $li++) {
        if ($script:languageList[$li].Code -eq [string]$global:language) { $cmbLanguage.SelectedIndex = $li }
    }
    $dlg.Controls.Add($cmbLanguage)
    $langToolTip = New-Object System.Windows.Forms.ToolTip
    $langToolTip.SetToolTip($cmbLanguage, 'Язык / Language / 语言 / Idioma / Sprache')

    $steamSection = New-Object System.Windows.Forms.Label
    $steamSection.Text = 'Steam'
    $steamSection.Location = New-Object System.Drawing.Point(20, 58)
    $steamSection.Size = New-Object System.Drawing.Size(520, 25)
    $steamSection.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10.5)
    $steamSection.ForeColor = $steamUi.Accent
    $dlg.Controls.Add($steamSection)

    $steamPathLabel = New-Object System.Windows.Forms.Label
    $steamPathLabel.Text = (T 'set_steam_folder')
    $steamPathLabel.Location = New-Object System.Drawing.Point(20, 92)
    $steamPathLabel.Size = New-Object System.Drawing.Size(100, 28)
    $steamPathLabel.ForeColor = $steamUi.Muted
    $steamPathLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $dlg.Controls.Add($steamPathLabel)

    $steamPathPanel = New-Object System.Windows.Forms.Panel
    $steamPathPanel.Location = New-Object System.Drawing.Point(120, 92)
    $steamPathPanel.Size = New-Object System.Drawing.Size(320, 30)
    $steamPathPanel.BackColor = $steamUi.Input
    $steamPathPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $dlg.Controls.Add($steamPathPanel)

    $txtSteamPath = New-Object System.Windows.Forms.TextBox
    $txtSteamPath.AutoSize = $false
    $txtSteamPath.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $txtSteamPath.BackColor = $steamUi.Input
    $txtSteamPath.ForeColor = $steamUi.Text
    $txtSteamPath.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $txtSteamPath.Text = [string](Get-ConfiguredSteamInstallPath)
    $txtSteamPath.Location = New-Object System.Drawing.Point(6, 4)
    $txtSteamPath.Size = New-Object System.Drawing.Size(308, 21)
    $steamPathPanel.Controls.Add($txtSteamPath)

    $btnBrowseSteamPath = New-Object System.Windows.Forms.Button
    $btnBrowseSteamPath.Text = (T 'browse')
    $btnBrowseSteamPath.Location = New-Object System.Drawing.Point(450, 92)
    $btnBrowseSteamPath.Size = New-Object System.Drawing.Size(90, 30)
    $btnBrowseSteamPath.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnBrowseSteamPath.FlatAppearance.BorderColor = $steamUi.Border
    $btnBrowseSteamPath.BackColor = $steamUi.Panel
    $btnBrowseSteamPath.ForeColor = $steamUi.Text
    $btnBrowseSteamPath.Cursor = [System.Windows.Forms.Cursors]::Hand
    $dlg.Controls.Add($btnBrowseSteamPath)

    $steamProfileLabel = New-Object System.Windows.Forms.Label
    $steamProfileLabel.Text = (T 'set_profile')
    $steamProfileLabel.Location = New-Object System.Drawing.Point(20, 132)
    $steamProfileLabel.Size = New-Object System.Drawing.Size(100, 28)
    $steamProfileLabel.ForeColor = $steamUi.Muted
    $steamProfileLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $dlg.Controls.Add($steamProfileLabel)

    $cmbSteamProfile = New-Object System.Windows.Forms.ComboBox
    $cmbSteamProfile.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $cmbSteamProfile.Location = New-Object System.Drawing.Point(120, 132)
    $cmbSteamProfile.Size = New-Object System.Drawing.Size(420, 30)
    $cmbSteamProfile.BackColor = $steamUi.Input
    $cmbSteamProfile.ForeColor = $steamUi.Text
    $cmbSteamProfile.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $dlg.Controls.Add($cmbSteamProfile)

    $steamProfileHint = New-Object System.Windows.Forms.Label
    $steamProfileHint.Text = (T 'set_profile_hint')
    $steamProfileHint.Location = New-Object System.Drawing.Point(120, 166)
    $steamProfileHint.Size = New-Object System.Drawing.Size(420, 22)
    $steamProfileHint.ForeColor = $steamUi.Muted
    $dlg.Controls.Add($steamProfileHint)

    $section = New-Object System.Windows.Forms.Label
    $section.Text = 'SteamGridDB'
    $section.Location = New-Object System.Drawing.Point(20, 202)
    $section.Size = New-Object System.Drawing.Size(520, 25)
    $section.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10.5)
    $section.ForeColor = $steamUi.Accent
    $dlg.Controls.Add($section)

    $keyLabel = New-Object System.Windows.Forms.Label
    $keyLabel.Text = (T 'set_api_key')
    $keyLabel.Location = New-Object System.Drawing.Point(20, 236)
    $keyLabel.Size = New-Object System.Drawing.Size(70, 28)
    $keyLabel.ForeColor = $steamUi.Muted
    $keyLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $dlg.Controls.Add($keyLabel)

    # Значок состояния API-ключа — точно такой же, как в карточке игры:
    # зелёная галочка для валидного ключа, красный ! для невалидного.
    # Он находится непосредственно перед полем ввода.
    $apiKeyValidationBadge = New-ConfidenceBadge $dlg 94 241

    $keyPanel = New-Object System.Windows.Forms.Panel
    $keyPanel.Location = New-Object System.Drawing.Point(120, 236)
    $keyPanel.Size = New-Object System.Drawing.Size(420, 30)
    $keyPanel.BackColor = $steamUi.Input
    $keyPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $dlg.Controls.Add($keyPanel)

    $txtKey = New-Object System.Windows.Forms.TextBox
    $txtKey.AutoSize = $false
    $txtKey.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $txtKey.BackColor = $steamUi.Input
    $txtKey.ForeColor = $steamUi.Text
    $txtKey.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $txtKey.Text = [string]$global:steamGridDbApiKey
    $txtKey.Location = New-Object System.Drawing.Point(6, 4)
    $txtKey.Size = New-Object System.Drawing.Size(408, 21)
    $keyPanel.Controls.Add($txtKey)

    # При открытии настроек НЕ выполняем повторную проверку API. Используем
    # результат проверки, уже полученный при запуске программы. Поэтому
    # зелёная галочка/красный ! сразу видны рядом с ключом.
    if (-not [string]::IsNullOrWhiteSpace([string]$global:steamGridDbApiKey)) {
        if ([bool]$global:steamGridDbApiKeyValid) {
            Set-ApiKeyValidationBadge $apiKeyValidationBadge 'valid' (T 'key_valid')
        } else {
            $startupCheck = $global:steamGridDbApiKeyCheck
            $startupMsg = if ($startupCheck -ne $null -and -not [string]::IsNullOrWhiteSpace([string]$startupCheck.Message)) { [string]$startupCheck.Message } else { (T 'key_invalid_default') }
            Set-ApiKeyValidationBadge $apiKeyValidationBadge 'invalid' $startupMsg
        }
    } else {
        Set-ApiKeyValidationBadge $apiKeyValidationBadge 'hidden' ''
    }

    # Проверяем ключ после окончания ввода, а не на каждый символ.
    # Это исключает десятки лишних HTTP-запросов во время вставки/набора ключа.
    $apiKeyValidationTimer = New-Object System.Windows.Forms.Timer
    $apiKeyValidationTimer.Interval = 650

    $apiKeyValidationTimer.Add_Tick({
        $apiKeyValidationTimer.Stop()
        $key = [string]$txtKey.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($key)) {
            $global:steamGridDbApiKeyValid = $false
            Set-ApiKeyValidationBadge $apiKeyValidationBadge 'hidden' ''
            & $applyKeyHint $null
            return
        }

        $global:steamGridDbApiKeyValid = $false
        # Запрос синхронный, поэтому заранее показываем "проверяю" и просим
        # перерисовать подпись — иначе она не успеет обновиться до ответа.
        $hint.Text = (T 'key_checking')
        $hint.ForeColor = $steamUi.Muted
        try { $hint.Refresh() } catch {}
        $check = Test-SteamGridDbApiKey $key
        if ($check.Valid) {
            Set-ApiKeyValidationBadge $apiKeyValidationBadge 'valid' $check.Message
        } else {
            # Красный ! и при неверном ключе, и при сетевом сбое; чем именно
            # это вызвано, объясняют tooltip и подпись под полем.
            Set-ApiKeyValidationBadge $apiKeyValidationBadge 'invalid' $check.Message
        }
        & $applyKeyHint $check
    })

    $txtKey.Add_TextChanged({
        $apiKeyValidationTimer.Stop()
        # После любого изменения ключ снова считается непроверенным, поэтому
        # кнопка SGDB в карточке игры должна стать неактивной до новой успешной проверки.
        $global:steamGridDbApiKeyValid = $false
        if ([string]::IsNullOrWhiteSpace([string]$txtKey.Text.Trim())) {
            Set-ApiKeyValidationBadge $apiKeyValidationBadge 'hidden' ''
            & $applyKeyHint $null
            return
        }
        Set-ApiKeyValidationBadge $apiKeyValidationBadge 'hidden' ''
        $hint.Text = (T 'key_checking')
        $hint.ForeColor = $steamUi.Muted
        $apiKeyValidationTimer.Start()
    })

    $dlg.Add_FormClosed({
        try { $apiKeyValidationTimer.Stop(); $apiKeyValidationTimer.Dispose() } catch {}
    })

    $hint = New-Object System.Windows.Forms.Label
    $hint.Text = (T 'key_hint_default')
    $hint.Location = New-Object System.Drawing.Point(120, 270)
    $hint.Size = New-Object System.Drawing.Size(420, 30)
    $hint.ForeColor = $steamUi.Muted
    $dlg.Controls.Add($hint)

    # Подпись под полем ключа: пока поле пустое — обычная подсказка (что это
    # за ключ и где его взять); когда ключ введён — результат его проверки:
    # зелёным (действителен), красным (ключ/доступ) или жёлтым (сервис не
    # ответил, ключ при этом не признан плохим).
    $hintDefaultText = [string]$hint.Text
    $hintColorError = [System.Drawing.Color]::FromArgb(232, 110, 110)
    $hintColorWarn = [System.Drawing.Color]::FromArgb(226, 180, 90)
    $applyKeyHint = {
        param($check)
        if ($check -eq $null -or [string]::IsNullOrWhiteSpace([string]$txtKey.Text)) {
            $hint.Text = $hintDefaultText
            $hint.ForeColor = $steamUi.Muted
            return
        }
        $hintText = [string]$check.Message
        # Для недействительного ключа сразу подсказываем, где взять новый.
        if ($check.Kind -eq 'invalid') { $hintText += (T 'key_new_key') }
        $hint.Text = $hintText
        if ($check.Severity -eq 'ok') { $hint.ForeColor = $steamUi.Green }
        elseif ($check.Severity -eq 'warn') { $hint.ForeColor = $hintColorWarn }
        else { $hint.ForeColor = $hintColorError }
    }
    # Начальное состояние — по результату проверки, сделанной при запуске.
    & $applyKeyHint $global:steamGridDbApiKeyCheck

    $backupSection = New-Object System.Windows.Forms.Label
    $backupSection.Text = (T 'set_backup_section')
    $backupSection.Location = New-Object System.Drawing.Point(20, 304)
    $backupSection.Size = New-Object System.Drawing.Size(520, 25)
    $backupSection.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10.5)
    $backupSection.ForeColor = $steamUi.Accent
    $dlg.Controls.Add($backupSection)

    # Кнопка выбора собственной папки для сохранения резервных копий —
    # первая в ряду, слева от «Создать бэкап».
    $btnBrowseBackupFolder = New-Object System.Windows.Forms.Button
    $btnBrowseBackupFolder.Text = (T 'browse')
    $btnBrowseBackupFolder.Location = New-Object System.Drawing.Point(20, 339)
    $btnBrowseBackupFolder.Size = New-Object System.Drawing.Size(145, 34)
    $btnBrowseBackupFolder.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnBrowseBackupFolder.FlatAppearance.BorderColor = $steamUi.Border
    $btnBrowseBackupFolder.BackColor = $steamUi.Panel
    $btnBrowseBackupFolder.ForeColor = $steamUi.Text
    $btnBrowseBackupFolder.Cursor = [System.Windows.Forms.Cursors]::Hand
    $dlg.Controls.Add($btnBrowseBackupFolder)

    $backupFolderTip = New-Object System.Windows.Forms.ToolTip
    $backupFolderTip.SetToolTip($btnBrowseBackupFolder, (T 'set_backup_current' @((Get-BackupFolderPath))))

    $btnCreateBackup = New-Object System.Windows.Forms.Button
    $btnCreateBackup.Text = (T 'set_create_backup')
    $btnCreateBackup.Location = New-Object System.Drawing.Point(175, 339)
    $btnCreateBackup.Size = New-Object System.Drawing.Size(145, 34)
    $btnCreateBackup.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnCreateBackup.FlatAppearance.BorderColor = $steamUi.Accent2
    $btnCreateBackup.BackColor = [System.Drawing.Color]::FromArgb(25,55,75)
    $btnCreateBackup.ForeColor = $steamUi.Text
    $btnCreateBackup.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
    $btnCreateBackup.Cursor = [System.Windows.Forms.Cursors]::Hand
    $dlg.Controls.Add($btnCreateBackup)

    $btnRestoreBackup = New-Object System.Windows.Forms.Button
    $btnRestoreBackup.Text = (T 'set_restore')
    $btnRestoreBackup.Location = New-Object System.Drawing.Point(330, 339)
    $btnRestoreBackup.Size = New-Object System.Drawing.Size(145, 34)
    $btnRestoreBackup.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnRestoreBackup.FlatAppearance.BorderColor = $steamUi.Accent2
    $btnRestoreBackup.BackColor = [System.Drawing.Color]::FromArgb(25,55,75)
    $btnRestoreBackup.ForeColor = $steamUi.Text
    $btnRestoreBackup.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
    $btnRestoreBackup.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnRestoreBackup.Visible = $false
    $dlg.Controls.Add($btnRestoreBackup)

    $lvBackups = New-Object System.Windows.Forms.ListView
    $lvBackups.Location = New-Object System.Drawing.Point(20, 382)
    $lvBackups.Size = New-Object System.Drawing.Size(520, 112)
    $lvBackups.View = [System.Windows.Forms.View]::Details
    $lvBackups.FullRowSelect = $true
    $lvBackups.GridLines = $false
    $lvBackups.HideSelection = $false
    $lvBackups.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $lvBackups.BackColor = $steamUi.Input
    $lvBackups.ForeColor = $steamUi.Text
    $lvBackups.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
    [void]$lvBackups.Columns.Add((T 'col_file'), 275)
    [void]$lvBackups.Columns.Add((T 'col_date'), 125)
    [void]$lvBackups.Columns.Add((T 'col_size'), 90)
    $dlg.Controls.Add($lvBackups)

    # Строка статуса для сообщений о создании/восстановлении резервных
    # копий («Готово к восстановлению», «Создано копий: N» и т.п.).
    $backupHint = New-Object System.Windows.Forms.Label
    $backupHint.Text = ''
    $backupHint.Location = New-Object System.Drawing.Point(20, 496)
    $backupHint.Size = New-Object System.Drawing.Size(520, 18)
    $backupHint.ForeColor = $steamUi.Muted
    $backupHint.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
    $dlg.Controls.Add($backupHint)

    $appVersionLabel = New-Object System.Windows.Forms.Label
    $appVersionLabel.Text = "$($global:appTitle) • v$($global:appVersion)"
    $appVersionLabel.Location = New-Object System.Drawing.Point(20, 515)
    $appVersionLabel.Size = New-Object System.Drawing.Size(300, 34)
    $appVersionLabel.ForeColor = $steamUi.Muted
    $appVersionLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $dlg.Controls.Add($appVersionLabel)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = (T 'set_cancel')
    $btnCancel.Location = New-Object System.Drawing.Point(335, 515)
    $btnCancel.Size = New-Object System.Drawing.Size(100, 34)
    $btnCancel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnCancel.FlatAppearance.BorderColor = $steamUi.Border
    $btnCancel.BackColor = $steamUi.Panel
    $btnCancel.ForeColor = $steamUi.Text
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $dlg.Controls.Add($btnCancel)

    $btnSave = New-Object System.Windows.Forms.Button
    $btnSave.Text = (T 'set_save')
    $btnSave.Location = New-Object System.Drawing.Point(440, 515)
    $btnSave.Size = New-Object System.Drawing.Size(100, 34)
    $btnSave.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnSave.FlatAppearance.BorderColor = $steamUi.Accent2
    $btnSave.BackColor = [System.Drawing.Color]::FromArgb(25,55,75)
    $btnSave.ForeColor = $steamUi.Text
    $btnSave.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
    $dlg.Controls.Add($btnSave)

    $refreshSteamProfiles = {
        try {
            $oldId = [string]$global:steamUserId
            $profiles = @(Get-SteamUserProfiles)

            $cmbSteamProfile.Items.Clear()
            $cmbSteamProfile.Tag = $profiles

            if ($profiles.Count -eq 0) {
                $cmbSteamProfile.Items.Add((T 'set_no_profiles')) | Out-Null
                $cmbSteamProfile.SelectedIndex = 0
                $cmbSteamProfile.Enabled = $false
                $steamProfileHint.Text = (T 'set_profile_none')
                return
            }

            $cmbSteamProfile.Enabled = $true
            foreach ($profile in $profiles) {
                [void]$cmbSteamProfile.Items.Add([string]$profile.DisplayName)
            }

            $selectedIndex = -1
            for ($i = 0; $i -lt $profiles.Count; $i++) {
                if ([string]::Equals([string]$profiles[$i].Id, $oldId, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $selectedIndex = $i
                    break
                }
            }
            if ($selectedIndex -lt 0) {
                $selectedIndex = 0
                $steamProfileHint.Text = (T 'set_profile_auto')
            } else {
                $steamProfileHint.Text = (T 'set_profile_chosen' @([string]$profiles[$selectedIndex].Id))
            }
            $cmbSteamProfile.SelectedIndex = $selectedIndex
        } catch {
            $cmbSteamProfile.Items.Clear()
            $cmbSteamProfile.Items.Add((T 'set_profiles_fail')) | Out-Null
            $cmbSteamProfile.SelectedIndex = 0
            $cmbSteamProfile.Enabled = $false
        }
    }

    $btnBrowseSteamPath.Add_Click({
        try {
            $res = Show-CenteredFolderDialog (T 'pick_steam_folder') $txtSteamPath.Text
            if ($res -ne $null) {
                $txtSteamPath.Text = [string]$res
                $global:steamInstallPath = [string]$res
                $global:steamUserId = ''
                & $refreshSteamProfiles
            }
        } catch {}
    })

    $cmbSteamProfile.Add_SelectionChangeCommitted({
        try {
            $profiles = @($cmbSteamProfile.Tag)
            $idx = $cmbSteamProfile.SelectedIndex
            if ($idx -ge 0 -and $idx -lt $profiles.Count) {
                $steamProfileHint.ForeColor = $steamUi.Muted
                $steamProfileHint.Text = (T 'set_profile_chosen' @([string]$profiles[$idx].Id))
            }
        } catch {}
    })

    & $refreshSteamProfiles

    $refreshBackupList = {
        try {
            $lvBackups.Items.Clear()
            $btnRestoreBackup.Visible = $false
            $btnRestoreBackup.Tag = $null
            foreach ($backup in @(Get-ManualShortcutBackupFiles)) {
                $item = $lvBackups.Items.Add([string]$backup.Name)
                [void]$item.SubItems.Add($backup.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
                $sizeText = if ($backup.Length -ge 1MB) {
                    ('{0:N1} ' -f ($backup.Length / 1MB)) + (T 'unit_mb')
                } elseif ($backup.Length -ge 1KB) {
                    ('{0:N0} ' -f ($backup.Length / 1KB)) + (T 'unit_kb')
                } else {
                    ('{0} ' -f $backup.Length) + (T 'unit_b')
                }
                [void]$item.SubItems.Add($sizeText)
                $item.Tag = $backup
            }
            if ($lvBackups.Items.Count -eq 0) {
                $empty = New-Object System.Windows.Forms.ListViewItem
                $empty.Text = (T 'no_backups')
                $empty.ForeColor = $steamUi.Muted
                [void]$empty.SubItems.Add('')
                [void]$empty.SubItems.Add('')
                [void]$lvBackups.Items.Add($empty)
            }
        } catch {
            try { $btnRestoreBackup.Visible = $false } catch {}
        }
    }

    # Небольшое тематическое окно подтверждения в стиле самого Commander.
    # Используется вместо стандартного Windows MessageBox при восстановлении.
    $showThemedRestoreConfirm = {
        param(
            [string]$windowTitle,
            [string]$messageText
        )

        $confirm = New-Object System.Windows.Forms.Form
        $confirm.Text = $windowTitle
        $confirm.StartPosition = 'CenterParent'
        $confirm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
        $confirm.MaximizeBox = $false
        $confirm.MinimizeBox = $false
        $confirm.ShowInTaskbar = $false
        $confirm.ClientSize = New-Object System.Drawing.Size(500, 190)
        $confirm.BackColor = $steamUi.Bg
        $confirm.ForeColor = $steamUi.Text
        $confirm.Font = New-Object System.Drawing.Font('Segoe UI', 9)

        $confirmTitle = New-Object System.Windows.Forms.Label
        $confirmTitle.Text = $windowTitle
        $confirmTitle.Location = New-Object System.Drawing.Point(20, 16)
        $confirmTitle.Size = New-Object System.Drawing.Size(460, 28)
        $confirmTitle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 12)
        $confirmTitle.ForeColor = $steamUi.Text
        $confirm.Controls.Add($confirmTitle)

        $confirmMessage = New-Object System.Windows.Forms.Label
        $confirmMessage.Text = $messageText
        $confirmMessage.Location = New-Object System.Drawing.Point(20, 52)
        $confirmMessage.Size = New-Object System.Drawing.Size(460, 62)
        $confirmMessage.ForeColor = $steamUi.Muted
        $confirmMessage.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $confirm.Controls.Add($confirmMessage)

        $btnConfirmYes = New-Object System.Windows.Forms.Button
        $btnConfirmYes.Text = (T 'set_restore')
        $btnConfirmYes.Location = New-Object System.Drawing.Point(235, 132)
        $btnConfirmYes.Size = New-Object System.Drawing.Size(120, 34)
        $btnConfirmYes.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btnConfirmYes.FlatAppearance.BorderColor = $steamUi.Accent2
        $btnConfirmYes.BackColor = [System.Drawing.Color]::FromArgb(25,55,75)
        $btnConfirmYes.ForeColor = $steamUi.Text
        $btnConfirmYes.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
        $btnConfirmYes.Cursor = [System.Windows.Forms.Cursors]::Hand
        $btnConfirmYes.DialogResult = [System.Windows.Forms.DialogResult]::Yes
        $confirm.Controls.Add($btnConfirmYes)

        $btnConfirmNo = New-Object System.Windows.Forms.Button
        $btnConfirmNo.Text = (T 'set_cancel')
        $btnConfirmNo.Location = New-Object System.Drawing.Point(365, 132)
        $btnConfirmNo.Size = New-Object System.Drawing.Size(115, 34)
        $btnConfirmNo.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btnConfirmNo.FlatAppearance.BorderColor = $steamUi.Border
        $btnConfirmNo.BackColor = $steamUi.Panel
        $btnConfirmNo.ForeColor = $steamUi.Text
        $btnConfirmNo.Cursor = [System.Windows.Forms.Cursors]::Hand
        $btnConfirmNo.DialogResult = [System.Windows.Forms.DialogResult]::No
        $confirm.Controls.Add($btnConfirmNo)

        $confirm.AcceptButton = $btnConfirmYes
        $confirm.CancelButton = $btnConfirmNo

        try {
            return ($confirm.ShowDialog($dlg) -eq [System.Windows.Forms.DialogResult]::Yes)
        } finally {
            try { $confirm.Dispose() } catch {}
        }
    }

    # Полностью закрывает Steam перед заменой shortcuts.vdf.
    # Путь возвращается в вызывающий код, где Steam запускается уже ПОСЛЕ
    # копирования восстановленного файла.
    $restartSteamAfterRestore = {
        try {
            $steamExe = $null

            # 0) Если Steam уже запущен, сначала запоминаем реальный путь
            # из самого процесса. Это надёжнее реестра для нестандартной установки.
            try {
                $runningForPath = @(Get-Process -Name 'steam' -ErrorAction SilentlyContinue | Select-Object -First 1)
                if ($runningForPath.Count -gt 0) {
                    try {
                        $procPath = [string]$runningForPath[0].Path
                        if ([string]::IsNullOrWhiteSpace($procPath)) {
                            $procPath = [string]$runningForPath[0].MainModule.FileName
                        }
                        if (-not [string]::IsNullOrWhiteSpace($procPath) -and (Test-Path -LiteralPath $procPath)) {
                            $steamExe = $procPath
                        }
                    } catch {
                        try {
                            $procPath = [string]$runningForPath[0].MainModule.FileName
                            if (-not [string]::IsNullOrWhiteSpace($procPath) -and (Test-Path -LiteralPath $procPath)) {
                                $steamExe = $procPath
                            }
                        } catch {}
                    }
                }
            } catch {}

            # 1) Путь из настроек программы (приоритетный).
            try {
                $configuredExe = Get-ConfiguredSteamExePath
                if (-not [string]::IsNullOrWhiteSpace([string]$configuredExe) -and (Test-Path -LiteralPath [string]$configuredExe)) {
                    $steamExe = [string]$configuredExe
                }
            } catch {}

            # 2) Резервный способ — путь Steam из реестра.
            if ([string]::IsNullOrWhiteSpace([string]$steamExe)) {
                try {
                    $steamExeReg = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamExe" -ErrorAction SilentlyContinue).SteamExe
                    if (-not [string]::IsNullOrWhiteSpace([string]$steamExeReg) -and (Test-Path -LiteralPath [string]$steamExeReg)) {
                        $steamExe = [string]$steamExeReg
                    }
                } catch {}
            }

            # Если Steam ещё работает — сначала просим его закрыться.
            $running = @(Get-Process -Name 'steam' -ErrorAction SilentlyContinue)
            if ($running.Count -gt 0) {
                foreach ($proc in $running) {
                    try {
                        if ($proc.MainWindowHandle -ne 0) {
                            [void]$proc.CloseMainWindow()
                        }
                    } catch {}
                }

                # Ждём завершения всех steam.exe, а не только главного окна.
                $deadline = (Get-Date).AddSeconds(12)
                while ((@(Get-Process -Name 'steam' -ErrorAction SilentlyContinue)).Count -gt 0 -and (Get-Date) -lt $deadline) {
                    Start-Sleep -Milliseconds 250
                }

                # Остались процессы — принудительно закрываем их.
                $leftovers = @(Get-Process -Name 'steam' -ErrorAction SilentlyContinue)
                foreach ($proc in $leftovers) {
                    try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
                }

                # Дожидаемся реального освобождения shortcuts.vdf.
                $deadline = (Get-Date).AddSeconds(6)
                while ((@(Get-Process -Name 'steam' -ErrorAction SilentlyContinue)).Count -gt 0 -and (Get-Date) -lt $deadline) {
                    Start-Sleep -Milliseconds 250
                }

                Start-Sleep -Milliseconds 500
            }

            if ([string]::IsNullOrWhiteSpace([string]$steamExe)) {
                $steamExe = 'steam.exe'
            }

            return [string]$steamExe
        } catch {
            return $null
        }
    }

    # Надёжный запуск Steam: обычный Start-Process + резервный запуск через
    # explorer.exe, затем проверяем, что процесс действительно появился.
    $startSteamAfterRestore = {
        param([string]$steamExe)

        try {
            if ([string]::IsNullOrWhiteSpace($steamExe)) { return $false }

            $launchPath = [string]$steamExe
            $workingDir = $null
            try { $workingDir = [System.IO.Path]::GetDirectoryName($launchPath) } catch {}

            if (Test-Path -LiteralPath $launchPath) {
                try {
                    if ([string]::IsNullOrWhiteSpace($workingDir)) {
                        Start-Process -FilePath $launchPath -ErrorAction Stop | Out-Null
                    } else {
                        Start-Process -FilePath $launchPath -WorkingDirectory $workingDir -ErrorAction Stop | Out-Null
                    }
                } catch {}

                # Steam иногда стартует не мгновенно — даём ему до 8 секунд.
                $deadline = (Get-Date).AddSeconds(8)
                while ((Get-Date) -lt $deadline) {
                    if (@(Get-Process -Name 'steam' -ErrorAction SilentlyContinue).Count -gt 0) {
                        return $true
                    }
                    Start-Sleep -Milliseconds 250
                }

                # Резерв: передаём запуск Windows Shell.
                try {
                    Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $launchPath + '"') -ErrorAction Stop | Out-Null
                } catch {}
            } else {
                # Путь не найден — полагаемся на зарегистрированный steam.exe.
                try {
                    Start-Process -FilePath 'steam.exe' -ErrorAction Stop | Out-Null
                } catch {}
            }

            $deadline = (Get-Date).AddSeconds(8)
            while ((Get-Date) -lt $deadline) {
                if (@(Get-Process -Name 'steam' -ErrorAction SilentlyContinue).Count -gt 0) {
                    return $true
                }
                Start-Sleep -Milliseconds 250
            }

            return $false
        } catch {
            return $false
        }
    }

    $lvBackups.Add_SelectedIndexChanged({
        try {
            $btnRestoreBackup.Visible = $false
            $btnRestoreBackup.Tag = $null
            if ($lvBackups.SelectedItems.Count -eq 0) { return }
            $selectedItem = $lvBackups.SelectedItems[0]
            $backup = $selectedItem.Tag
            if ($backup -eq $null -or -not ($backup -is [System.IO.FileInfo])) { return }
            $target = Resolve-ManualBackupTarget $backup
            if ($target -eq $null) {
                $backupHint.Text = (T 'bk_no_source')
                return
            }
            $btnRestoreBackup.Tag = [PSCustomObject]@{ Backup = $backup; Target = [string]$target }
            $btnRestoreBackup.Visible = $true
            $backupHint.Text = (T 'bk_ready')
        } catch {
            $btnRestoreBackup.Visible = $false
            $btnRestoreBackup.Tag = $null
        }
    })

    $btnBrowseBackupFolder.Add_Click({
        try {
            $res = Show-CenteredFolderDialog (T 'pick_backup_folder') (Get-BackupFolderPath)
            if ($res -ne $null -and -not [string]::IsNullOrWhiteSpace([string]$res)) {
                $global:backupFolderPath = [string]$res
                $backupFolderTip.SetToolTip($btnBrowseBackupFolder, (T 'set_backup_current' @((Get-BackupFolderPath))))
                & $refreshBackupList
            }
        } catch {}
    })

    $btnCreateBackup.Add_Click({
        $btnCreateBackup.Enabled = $false
        try {
            $created = @(Create-ManualShortcutBackup)
            & $refreshBackupList
            if ($created.Count -gt 0) {
                $backupHint.Text = (T 'bk_created' @($created.Count))
            } else {
                $backupHint.Text = (T 'bk_vdf_missing')
            }
        } finally {
            $btnCreateBackup.Enabled = $true
        }
    })

    $btnRestoreBackup.Add_Click({
        try {
            $payload = $btnRestoreBackup.Tag
            if ($payload -eq $null) { return }
            $backup = $payload.Backup
            $target = $payload.Target
            if ($backup -eq $null -or [string]::IsNullOrWhiteSpace([string]$target)) { return }

            $confirmed = & $showThemedRestoreConfirm (T 'confirm_title') (
                (T 'confirm_q' @([string]$backup.Name)) + "`r`n`r`n" + (T 'confirm_note')
            )
            if (-not $confirmed) { return }

            $btnRestoreBackup.Enabled = $false
            $btnCreateBackup.Enabled = $false
            $backupHint.Text = (T 'bk_closing')
            [System.Windows.Forms.Application]::DoEvents()

            $steamExe = & $restartSteamAfterRestore
            if ([string]::IsNullOrWhiteSpace([string]$steamExe)) {
                $backupHint.Text = (T 'bk_no_steam_path')
                return
            }

            $targetDir = [System.IO.Path]::GetDirectoryName([string]$target)
            if (-not [string]::IsNullOrWhiteSpace($targetDir)) {
                [System.IO.Directory]::CreateDirectory([string]$targetDir) | Out-Null
            }

            $backupHint.Text = (T 'bk_restoring')
            [System.Windows.Forms.Application]::DoEvents()

            Copy-Item -LiteralPath $backup.FullName -Destination ([string]$target) -Force -ErrorAction Stop

            $backupHint.Text = (T 'bk_starting')
            [System.Windows.Forms.Application]::DoEvents()

            $steamStarted = & $startSteamAfterRestore ([string]$steamExe)
            if ($steamStarted) {
                $backupHint.Text = (T 'bk_restored_ok' @([string]$backup.Name))
            } else {
                $backupHint.Text = (T 'bk_restored_nosteam')
            }
            try { [System.Media.SystemSounds]::Asterisk.Play() } catch {}
            & $refreshBackupList
            try { Refresh-Panels } catch {}
        } catch {
            $backupHint.Text = (T 'bk_restore_err' @([string]$_.Exception.Message))
        } finally {
            $btnRestoreBackup.Enabled = $true
            $btnCreateBackup.Enabled = $true
        }
    })

    & $refreshBackupList

    $btnSave.Add_Click({
        try {
            $chosenSteamPath = [string]$txtSteamPath.Text.Trim()
            if ([string]::IsNullOrWhiteSpace($chosenSteamPath)) {
                $steamProfileHint.ForeColor = $steamUi.Accent
                $steamProfileHint.Text = (T 'set_path_empty')
                return
            }

            $fullSteamPath = [System.IO.Path]::GetFullPath($chosenSteamPath)
            if (-not (Test-Path -LiteralPath $fullSteamPath -PathType Container)) {
                $steamProfileHint.ForeColor = $steamUi.Accent
                $steamProfileHint.Text = (T 'set_path_missing')
                return
            }

            $steamExeCandidate = Join-Path $fullSteamPath 'steam.exe'
            if (-not (Test-Path -LiteralPath $steamExeCandidate -PathType Leaf)) {
                $steamProfileHint.ForeColor = $steamUi.Accent
                $steamProfileHint.Text = (T 'set_exe_missing')
                return
            }

            $profiles = @($cmbSteamProfile.Tag)
            $idx = $cmbSteamProfile.SelectedIndex
            $chosenUserId = ''
            if ($cmbSteamProfile.Enabled -and $idx -ge 0 -and $idx -lt $profiles.Count) {
                $chosenUserId = [string]$profiles[$idx].Id
            }

            $global:steamInstallPath = $fullSteamPath
            $global:steamUserId = $chosenUserId
            $global:steamGridDbApiKey = $txtKey.Text.Trim()
            $settingsAccepted = $true

            # Язык: применяем к главному окну сразу, диалоги подхватят его при следующем открытии.
            $langIdx = $cmbLanguage.SelectedIndex
            if ($langIdx -ge 0 -and $langIdx -lt $script:languageList.Count) {
                $newLang = [string]$script:languageList[$langIdx].Code
                if ($newLang -ne [string]$global:language) {
                    $global:language = $newLang
                    try { Apply-Localization } catch {}
                }
            }

            Save-Configuration
            try { Refresh-Panels } catch {}
            $dlg.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $dlg.Close()
        } catch {
            $steamProfileHint.ForeColor = $steamUi.Accent
            $steamProfileHint.Text = (T 'set_save_err' @([string]$_.Exception.Message))
        }
    })

    $dlg.AcceptButton = $btnSave
    $dlg.CancelButton = $btnCancel
    # При открытии настроек ничего не выделяем и не ставим курсор в поле ключа.
    $dlg.Add_Shown({
        try {
            $txtKey.SelectionLength = 0
            $txtKey.SelectionStart = 0
            $dlg.ActiveControl = $null
            $dlg.Select()
        } catch {}
        try {
            $dlg.BeginInvoke([Action]{
                try {
                    $txtKey.SelectionLength = 0
                    $txtKey.SelectionStart = 0
                    $dlg.ActiveControl = $null
                } catch {}
            }) | Out-Null
        } catch {}
    })

    $dlg.Add_FormClosed({
        try {
            if (-not $settingsAccepted) {
                $global:steamInstallPath = $originalSteamInstallPath
                $global:steamUserId = $originalSteamUserId
            }
        } catch {}
    })

    # ВАЖНО: при простом открытии настроек повторную проверку сохранённого
    # ключа не запускаем. Ключ уже был проверен при старте программы.
    # Повторная проверка выполняется только после изменения значения в поле.

    $dlg.ShowDialog() | Out-Null

    return [string]$global:steamGridDbApiKey
}


function Get-EditorSgdbCandidates([string]$query, [string]$steamAppId = "") {
    # Автодополнение названия берём напрямую из SteamGridDB — это та же
    # рабочая логика, которая использовалась в старом picker-е.
    try {
        $q = ([string]$query).Trim()
        if ($q.Length -lt 2) { return @() }

        $apiKey = [string](Ensure-SteamGridDbApiKey)
        if ([string]::IsNullOrWhiteSpace($apiKey)) { return @() }
        $headers = @{ Authorization = "Bearer $apiKey" }

        $searchQueries = @($q)
        $tokens = @([regex]::Matches($q,'[\p{L}\p{Nd}]+') | ForEach-Object { [string]$_.Value })
        if ($tokens.Count -gt 1) {
            $fallback = (($tokens | Select-Object -First ([Math]::Min(3,[int]$tokens.Count))) -join ' ')
            if ($fallback -and $fallback -ne $q) { $searchQueries += $fallback }
        }

        # Та же обработка 401, что и в Load-EditorSgdbPreviews — через общую
        # обёртку Invoke-SgdbApiRequest вместо продублированной вручную ветки.
        $req = $null
        foreach($searchQuery in $searchQueries) {
            $url = 'https://www.steamgriddb.com/api/v2/search/autocomplete/' + [System.Uri]::EscapeDataString($searchQuery)
            $req = Invoke-SgdbApiRequest $url $headers 12
            if ($req.Success) { break }
        }

        if ($req -eq $null -or -not $req.Success) { return @() }

        $candidates = @($req.Data | ForEach-Object {
            if ($null -eq $_) { return }
            $id = 0
            try { $id = [int]$_.id } catch { $id = 0 }
            $nm = [string]$_.name
            if ($id -le 0 -or [string]::IsNullOrWhiteSpace($nm)) { return }
            $types = @()
            try { $types = @($_.types) } catch {}
            $score = 0.0
            try { $score = [double](Get-SgdbNameScore $q $_) } catch {}
            [PSCustomObject]@{ Id=$id; Name=$nm; Verified=$_.verified; Types=$types; MatchScore=$score }
        } | Sort-Object MatchScore -Descending | Select-Object -First 12)

        # SteamGridDB id — это НЕ Steam App ID. Используем App ID только
        # для предпочтения steam-совместимых кандидатов, но не записываем его
        # в поле App ID при выборе названия.
        if ($steamAppId -match '^\d+$') {
            $steamMatch = @($candidates | Where-Object { @($_.Types) -contains 'steam' })
            if ($steamMatch.Count -gt 0) {
                $candidates = @($steamMatch + @($candidates | Where-Object { $_ -notin $steamMatch }))
            }
        }
        return @($candidates)
    } catch {
        $global:lastSgdbEditorError = [string]$_.Exception.Message
        return @()
    }
}

function Prepare-EditorSteamSgdbAlternatives($slot, [string]$title, [string]$steamAppId) {
    # В источнике Steam миниатюра остаётся официальной Steam, но по клику
    # пользователь может открыть SGDB только для ЭТОГО типа обложки.
    # Источник поиска карточки при этом не переключается.
    try {
        if ($null -eq $slot) { return $false }
        $id = ([string]$steamAppId).Trim()
        if ([string]::IsNullOrWhiteSpace($id) -or $id -notmatch '^\d+$') {
            return $false
        }

        # Если для этого слота варианты уже были загружены ранее — повторный
        # сетевой запрос не нужен.
        try {
            if (@($slot.SgdbItems).Count -gt 0) { return $true }
        } catch {}

        $apiKey = [string](Ensure-SteamGridDbApiKey)
        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            return $false
        }

        $slotForm = $null
        try { $slotForm = $slot.Panel.FindForm() } catch {}
        $statusLabel = $null
        try {
            if ($null -ne $slotForm) {
                $statusLabel = @($slotForm.Controls | Where-Object { $_ -is [System.Windows.Forms.Label] -and $_.Location.X -eq 20 -and $_.Location.Y -eq 111 }) | Select-Object -First 1
            }
        } catch {}
        if ($null -ne $statusLabel) {
            $statusLabel.Text = (T 'sl_sg_alts' @($title))
        }
        [System.Windows.Forms.Application]::DoEvents()

        $assets = Get-SteamGridDbAssetsBySteamAppId $id
        if ($null -eq $assets) { return $false }

        $items = @()
        switch -Regex ($title) {
            '^\s*1\.' {
                $items = @($assets.Grids | Where-Object {
                    $w=0;$h=0;try{$w=[int]$_.width;$h=[int]$_.height}catch{}
                    (($w -eq 600 -and $h -eq 900) -or
                     ($w -eq 342 -and $h -eq 482) -or
                     ($w -eq 660 -and $h -eq 930))
                })
                if ($items.Count -eq 0) {
                    $items = @($assets.Grids | Where-Object {
                        $w=0;$h=0;try{$w=[double]$_.width;$h=[double]$_.height}catch{}
                        $h -gt 0 -and ($w/$h) -ge 0.55 -and ($w/$h) -le 0.78
                    })
                }
            }
            '^\s*2\.' {
                $items = @($assets.Grids | Where-Object {
                    $w=0;$h=0;try{$w=[int]$_.width;$h=[int]$_.height}catch{}
                    (($w -eq 920 -and $h -eq 430) -or ($w -eq 460 -and $h -eq 215))
                })
                if ($items.Count -eq 0) {
                    $items = @($assets.Grids | Where-Object {
                        $w=0;$h=0;try{$w=[double]$_.width;$h=[double]$_.height}catch{}
                        $h -gt 0 -and ($w/$h) -ge 1.85 -and ($w/$h) -le 2.35
                    })
                }
            }
            '^\s*3\.' { $items = @($assets.Heroes) }
            '^\s*4\.' { $items = @($assets.Logos) }
        }

        if ($items.Count -eq 0) {
            if ($null -ne $statusLabel) { $statusLabel.Text = (T 'sl_sg_noalts') }
            return $false
        }

        $items = @($items | Sort-Object @{Expression={ $v=0.0; try{$v=[double]$_.score}catch{}; $v }; Descending=$true})
        $slot.SgdbItems = $items
        if ($null -ne $statusLabel) { $statusLabel.Text = (T 'sl_steam_loaded_alt') }
        return $true
    } catch {
        try {
            $form = $slot.Panel.FindForm()
            [System.Windows.Forms.MessageBox]::Show(
                (T 'sg_variants_fail' @([string]$_.Exception.Message)),
                'SteamGridDB',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
        } catch {}
        return $false
    }
}

function Show-EditorAlternativeCover($slot, [string]$title) {
    try {
        $items = @($slot.SgdbItems)
        if ($items.Count -eq 0) {
            return
        }

        $chooserWidth = 170
        $chooserHeight = 230
        if ($title -match '^\s*[234]\.') {
            $chooserWidth = 270
            $chooserHeight = 130
        }

        $chosen = Show-SgdbAssetChooser $title $items $chooserWidth $chooserHeight $slot.Panel.FindForm()
        if ([string]::IsNullOrWhiteSpace([string]$chosen)) {
            return
        }

        $fileName = switch -Regex ($title) {
            '^\s*1\.' { 'temp_p.jpg'; break }
            '^\s*2\.' { 'temp_header.jpg'; break }
            '^\s*3\.' { 'temp_hero.jpg'; break }
            '^\s*4\.' { 'temp_logo.png'; break }
            default { return }
        }
        $target = Join-Path $global:tempCovers $fileName

        # Используем тот же рабочий загрузчик, что и в старой версии.
        # Замена обложки — это тоже загрузка миниатюры, поэтому на время
        # скачивания показываем на слоте анимацию, а не пустой квадрат/крест.
        $slotForm = $null
        try { $slotForm = $slot.Panel.FindForm() } catch {}
        Set-EditorSlotLoading $slot $true
        try { if ($null -ne $slotForm -and $null -ne $slotForm.Tag -and $null -ne $slotForm.Tag.EditorLoadTimer) { $slotForm.Tag.EditorLoadTimer.Start() } } catch {}
        $global:uiPumpDuringDownload = $true
        try { if ($null -ne $slotForm) { $slotForm.Cursor = [System.Windows.Forms.Cursors]::WaitCursor } } catch {}
        try {
            if (Download-RemoteImage ([string]$chosen) $target) {
                if (Set-EditorPreviewFile $slot $target) {
                    Set-EditorSourceBadge $slot 'SteamGridDB'
                    $slot.SgdbSelectedUrl = [string]$chosen
                }
            }
        } finally {
            $global:uiPumpDuringDownload = $false
            Set-EditorSlotLoading $slot $false
            Set-EditorMissingState $slot ([bool]$slot.PendingMissing)
            # Таймер анимации останавливаем только если больше ничего не грузится.
            try {
                if ($null -ne $slotForm -and $null -ne $slotForm.Tag -and $null -ne $slotForm.Tag.EditorLoadTimer) {
                    $stillLoading = $false
                    foreach($other in $slotForm.Tag.EditorSlots.Values) { if ($other.IsLoading) { $stillLoading = $true } }
                    if (-not $stillLoading) { $slotForm.Tag.EditorLoadTimer.Stop() }
                }
            } catch {}
            try { if ($null -ne $slotForm) { $slotForm.Cursor = [System.Windows.Forms.Cursors]::Default } } catch {}
        }
    } catch {
        try {
            [System.Windows.Forms.MessageBox]::Show(
                (T 'sg_pick_fail' @([string]$_.Exception.Message)),
                'SteamGridDB',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
        } catch {}
    }
}

# ===================== ЗНАЧКИ УВЕРЕННОСТИ (Название / EXE) =====================
# Маленький кружок рядом с полем: зелёная галочка — программа сама уверенно
# определила значение, красный восклицательный знак — не смогла и нужна
# ручная проверка. Рисуется кодом (без файлов assets), чтобы не плодить
# лишние ресурсы под два простых состояния.
function Get-ConfidenceBadgeBitmap([bool]$confident) {
    try {
        $size = 18
        $bmp = New-Object System.Drawing.Bitmap $size, $size
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        try {
            $g.Clear([System.Drawing.Color]::Transparent)
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

            $fill = if ($confident) { [System.Drawing.Color]::FromArgb(255, 67, 181, 129) } else { [System.Drawing.Color]::FromArgb(255, 224, 82, 82) }
            $border = if ($confident) { [System.Drawing.Color]::FromArgb(255, 45, 140, 101) } else { [System.Drawing.Color]::FromArgb(255, 176, 50, 50) }
            $brush = New-Object System.Drawing.SolidBrush($fill)
            $pen = New-Object System.Drawing.Pen($border, 1.4)
            $g.FillEllipse($brush, 1, 1, $size - 2, $size - 2)
            $g.DrawEllipse($pen, 1, 1, $size - 2, $size - 2)

            $glyphPen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 2.1)
            $glyphPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
            $glyphPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
            if ($confident) {
                $pts = @(
                    (New-Object System.Drawing.PointF(4.5, 9.3)),
                    (New-Object System.Drawing.PointF(7.6, 12.6)),
                    (New-Object System.Drawing.PointF(13.5, 5.6))
                )
                $g.DrawLines($glyphPen, $pts)
            } else {
                $g.DrawLine($glyphPen, 9, 4.3, 9, 10.6)
                $dotBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
                $g.FillEllipse($dotBrush, 7.9, 12.3, 2.2, 2.2)
                $dotBrush.Dispose()
            }
            $glyphPen.Dispose(); $pen.Dispose(); $brush.Dispose()
        } finally { $g.Dispose() }
        return $bmp
    } catch { return $null }
}

function New-ConfidenceBadge($parent, [int]$x, [int]$y) {
    $pb = New-Object System.Windows.Forms.PictureBox
    $pb.Size = New-Object System.Drawing.Size(18, 18)
    $pb.Location = New-Object System.Drawing.Point($x, $y)
    $pb.BackColor = [System.Drawing.Color]::Transparent
    $pb.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    $pb.Cursor = [System.Windows.Forms.Cursors]::Default
    $pb.Visible = $false
    $parent.Controls.Add($pb)
    $pb.BringToFront()
    return $pb
}

function Set-ConfidenceBadge($pictureBox, [bool]$confident, [string]$confidentTip, [string]$unsureTip) {
    try {
        if ($null -eq $pictureBox) { return }
        $bmp = Get-ConfidenceBadgeBitmap $confident
        try { if ($null -ne $pictureBox.Image) { $pictureBox.Image.Dispose() } } catch {}
        $pictureBox.Image = $bmp
        $pictureBox.Visible = ($null -ne $bmp)
        try {
            if ($null -eq $pictureBox.Tag -or $pictureBox.Tag -isnot [System.Windows.Forms.ToolTip]) {
                $tt = New-Object System.Windows.Forms.ToolTip
                $pictureBox.Tag = $tt
            }
            $tip = if ($confident) { $confidentTip } else { $unsureTip }
            $pictureBox.Tag.SetToolTip($pictureBox, $tip)
        } catch {}
    } catch {}
}

function Show-GameEditorDialog($gameName, $source, $gamePath, [bool]$batchMode = $false, $batchHost = $null) {
    if($batchMode){ $script:batchCardCancelRequested = $false; $script:batchCardSkipRequested = $false }
    $editMode = $false
    $existingShortcut = $null
    # Steam перезапускается после закрытия карточки только если он правда был
    # убит (taskkill) в этой сессии карточки — то есть при реальном сохранении
    # изменений. Раньше перезапуск срабатывал всегда при editMode, даже если
    # пользователь просто открыл и закрыл/отменил карточку: Steam ни разу не
    # закрывался, но всё равно поднимался на передний план, из-за чего главное
    # окно программы (и всё, что было под ним) уходило в фон без причины.
    $steamWasKilledThisSession = $false
    if(-not $batchMode){
        try { $existingShortcut = Find-SteamShortcutRecord $gameName $gamePath } catch { $existingShortcut = $null }
        if($existingShortcut -ne $null){
            $editMode = $true
            if(-not [string]::IsNullOrWhiteSpace([string]$existingShortcut.AppName)){ $gameName=[string]$existingShortcut.AppName }
        }
    }
    # Все элементы верхней строки выровнены по общей вертикали: Y=14, высота=28 px.
    # Подписи центрируются относительно этой строки отдельной координатой Y=17.
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = (T 'card_title' @($gameName))
    $dlg.Size = New-Object System.Drawing.Size(900, 735)
    if($batchHost -ne $null){
        # Встраивание карточки как дочернего контрола в панель отдельного окна
        # пакета сейчас никем не используется (и авто-пакет, и обычный пакет
        # открывают карточку отдельным диалогом — см. ветку else ниже), но
        # параметр $batchHost оставлен на случай, если такой режим встраивания
        # понадобится снова.
        $dlg.TopLevel = $false
        $dlg.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
        $dlg.StartPosition = 'Manual'
        $dlg.Location = New-Object System.Drawing.Point(0, 0)
    } else {
        $dlg.StartPosition = "CenterParent"
        $dlg.FormBorderStyle = "FixedDialog"
    }
    $dlg.MaximizeBox = $false
    $dlg.BackColor = $steamUi.Bg
    $dlg.ForeColor = $steamUi.Text
    $dlg.Font = New-Object System.Drawing.Font("Segoe UI", 9)

    # Во время первичного открытия карточки ни одно поле ввода не должно получать
    # фокус автоматически. WinForms обычно передаёт фокус первому доступному
    # TextBox, из-за чего при установке/обновлении текста он может визуально
    # выделиться целиком (особенно пока загрузка обложек прокачивает UI через
    # Application.DoEvents()). Невидимая точка фокуса — маленькая кнопка вне
    # рабочей области — принимает фокус на время начальной загрузки. После этого
    # пользователь сам кликает/переходит в нужное поле.
    $editorFocusSink = New-Object System.Windows.Forms.Button
    $editorFocusSink.Name = 'EditorFocusSink'
    $editorFocusSink.Text = ''
    $editorFocusSink.Location = New-Object System.Drawing.Point(0,0)
    $editorFocusSink.Size = New-Object System.Drawing.Size(1,1)
    $editorFocusSink.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $editorFocusSink.FlatAppearance.BorderSize = 0
    $editorFocusSink.BackColor = $steamUi.Bg
    $editorFocusSink.ForeColor = $steamUi.Bg
    $editorFocusSink.TabStop = $false
    $editorFocusSink.Cursor = [System.Windows.Forms.Cursors]::Default
    $dlg.Controls.Add($editorFocusSink)

    $titleLbl = New-Object System.Windows.Forms.Label; $titleLbl.Text=(T 'card_name'); $titleLbl.Location='20,14'; $titleLbl.Size='90,28'; $titleLbl.ForeColor=$steamUi.Muted; $titleLbl.TextAlign=[System.Drawing.ContentAlignment]::MiddleLeft; $dlg.Controls.Add($titleLbl)
    # Значок уверенности в названии: зелёная галочка — Steam/SGDB подтвердили
    # это название, красный "!" — совпадение не найдено, нужна ручная проверка.
    $titleConfidenceBadge = New-ConfidenceBadge $dlg 91 19
    # Название — отдельное поле ввода. Список результатов больше НЕ является частью
    # ComboBox: это принципиально важно, потому что WinForms ComboBox может менять
    # Text/SelectedIndex при Clear/Add Items. Теперь поиск вообще не имеет права
    # менять введённый текст — он только обновляет отдельный нативный ComboBox-popup под полем.
    #
    # Однострочный TextBox в WinForms игнорирует заданную высоту и сам сжимается
    # до "предпочтительной" высоты под текущий шрифт, поэтому рамка рисовалась не
    # по тем 28px, что мы просили, и текст внутри казался прижатым кверху
    # относительно соседних кнопок/подписей. Чтобы получить ровно 28px высоты с
    # текстом строго по центру, рамку и фон теперь рисует Panel, а сам TextBox
    # лежит внутри неё без своей рамки и центрируется по вертикали вручную.
    $pnlTitle = New-Object System.Windows.Forms.Panel
    $pnlTitle.Location='115,14'; $pnlTitle.Size='420,28'
    $pnlTitle.BackColor=$steamUi.Input; $pnlTitle.BorderStyle='FixedSingle'
    $dlg.Controls.Add($pnlTitle)

    $txtTitle = New-Object System.Windows.Forms.TextBox
    $txtTitle.Text=$gameName; $txtTitle.AutoSize=$false; $txtTitle.BorderStyle='None'
    $txtTitle.BackColor=$steamUi.Input; $txtTitle.ForeColor=$steamUi.Text
    $txtTitle.Font=New-Object System.Drawing.Font('Segoe UI',9)
    $pnlTitle.Controls.Add($txtTitle)
    $txtTitle.Width = $pnlTitle.ClientSize.Width - 10
    $txtTitle.Location = New-Object System.Drawing.Point(5, [int](($pnlTitle.ClientSize.Height - $txtTitle.PreferredHeight) / 2))

    # Результаты — отдельный ComboBox только для ВЫБОРА результата.
    # Он лежит под TextBox и используется только как нативный выпадающий popup.
    # Поэтому список можно раскрывать настоящей стрелкой/Popup WinForms, но его
    # Items никогда не связаны с текстом, который пользователь редактирует.
    $titleResults = New-Object System.Windows.Forms.ListBox
    $titleResults.Location=New-Object System.Drawing.Point(115,43)
    $titleResults.Size=New-Object System.Drawing.Size(420,180)
    $titleResults.BackColor=$steamUi.Input; $titleResults.ForeColor=$steamUi.Text
    $titleResults.BorderStyle=[System.Windows.Forms.BorderStyle]::FixedSingle
    $titleResults.Font=New-Object System.Drawing.Font('Segoe UI',9)
    $titleResults.SelectionMode=[System.Windows.Forms.SelectionMode]::One
    $titleResults.IntegralHeight=$false
    $titleResults.Visible=$false
    $titleResults.TabStop=$false
    $dlg.Controls.Add($titleResults)

    # Высота списка зависит от фактического количества результатов.
    # Если результатов немного — не оставляем большой пустой тёмный блок.
    # При большом количестве сохраняем ограничение 180 px и стандартную
    # прокрутку ListBox.
    $resizeEditorTitleResults = {
        try {
            $count = [int]$titleResults.Items.Count
            if($count -le 0){
                $titleResults.Height = 20
                return
            }
            # Берём фактическую высоту последней строки ListBox, а не Font.Height.
            # Font.Height немного больше реальной строки элемента, из-за чего
            # при небольшом количестве результатов снизу появлялись лишние строки.
            try {
                $lastRect = $titleResults.GetItemRectangle($count - 1)
                $newHeight = [int]$lastRect.Bottom + 2
            } catch {
                $rowHeight = [Math]::Max(14, [int]$titleResults.ItemHeight)
                $newHeight = ($count * $rowHeight) + 2
            }
            $newHeight = [Math]::Min(180, [Math]::Max(20, $newHeight))
            $titleResults.Height = [int]$newHeight
        } catch {}
    }

    $titleResults.BringToFront()
    $pnlTitle.BringToFront()

    # Переключатель источника поиска. По умолчанию — Steam.
    # Steam использует Steam App ID, SGDB — SteamGridDB Game ID.
    $searchSteamBtn = New-Object System.Windows.Forms.Button
    $searchSteamBtn.Text='Steam'
    $searchSteamBtn.Location='540,14'; $searchSteamBtn.Size='74,28'
    $searchSteamBtn.FlatStyle='Flat'; $searchSteamBtn.FlatAppearance.BorderColor=$steamUi.Accent2
    $searchSteamBtn.Font=New-Object System.Drawing.Font('Segoe UI Semibold',8.5)
    $searchSteamBtn.Cursor=[System.Windows.Forms.Cursors]::Hand
    $dlg.Controls.Add($searchSteamBtn)

    $searchSgdbBtn = New-Object System.Windows.Forms.Button
    $searchSgdbBtn.Text='SGDB'
    $searchSgdbBtn.Location='614,14'; $searchSgdbBtn.Size='74,28'
    $searchSgdbBtn.FlatStyle='Flat'; $searchSgdbBtn.FlatAppearance.BorderColor=$steamUi.Border
    $searchSgdbBtn.Font=New-Object System.Drawing.Font('Segoe UI Semibold',8.5)
    $searchSgdbBtn.Cursor=[System.Windows.Forms.Cursors]::Hand
    $dlg.Controls.Add($searchSgdbBtn)

    # Значки на кнопках источников: значок слева от текста, вместе центрируются.
    foreach ($srcBtnDef in @(
        @{ Btn = $searchSteamBtn; Bmp = (Get-SteamSourceIconBitmap) },
        @{ Btn = $searchSgdbBtn;  Bmp = (Get-SteamGridDbSourceIconBitmap) }
    )) {
        try {
            $pair = New-SourceButtonIconPair $srcBtnDef.Bmp
            if ($null -ne $pair) {
                $srcBtnDef.Btn.Tag = $pair
                $srcBtnDef.Btn.Image = $pair.Dim
                $srcBtnDef.Btn.ImageAlign = [System.Drawing.ContentAlignment]::MiddleCenter
                $srcBtnDef.Btn.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
                $srcBtnDef.Btn.TextImageRelation = [System.Windows.Forms.TextImageRelation]::ImageBeforeText
                $srcBtnDef.Btn.Padding = New-Object System.Windows.Forms.Padding(0)
            }
            if ($null -ne $srcBtnDef.Bmp) { $srcBtnDef.Bmp.Dispose() }
        } catch {}
    }

    # SGDB доступен только после успешной проверки API-ключа. Пустой, изменённый,
    # невалидный или не проверенный ключ оставляет переключатель серым и неактивным.
    $updateSgdbButtonState = {
        $isValid = ([bool]$global:steamGridDbApiKeyValid -and -not [string]::IsNullOrWhiteSpace([string]$global:steamGridDbApiKey))
        $searchSgdbBtn.Enabled = $isValid
        if($isValid){
            # Если сейчас выбран SGDB, кнопка должна сохранять подсветку активного
            # источника. Раньше эта функция после переключения на SGDB повторно
            # задавала обычный (неактивный) стиль и тем самым снимала подсветку.
            if($editorState -ne $null -and $editorState.SearchSource -eq 'SteamGridDB'){
                $searchSgdbBtn.BackColor=$steamUi.Accent2
                $searchSgdbBtn.ForeColor=[System.Drawing.Color]::White
                $searchSgdbBtn.FlatAppearance.BorderColor=$steamUi.Accent2
            } else {
                $searchSgdbBtn.BackColor=$steamUi.Panel
                $searchSgdbBtn.ForeColor=$steamUi.Muted
                $searchSgdbBtn.FlatAppearance.BorderColor=$steamUi.Border
            }
            $searchSgdbBtn.Cursor=[System.Windows.Forms.Cursors]::Hand
        } else {
            $searchSgdbBtn.BackColor=[System.Drawing.Color]::FromArgb(45,45,45)
            $searchSgdbBtn.ForeColor=[System.Drawing.Color]::FromArgb(105,105,105)
            $searchSgdbBtn.FlatAppearance.BorderColor=[System.Drawing.Color]::FromArgb(65,65,65)
            $searchSgdbBtn.Cursor=[System.Windows.Forms.Cursors]::Default
        }
    }
    & $updateSgdbButtonState

    # Состояние источника хранится в объекте, а не в локальной переменной: PowerShell
    # создаёт отдельную область видимости для обработчиков событий и из-за обычного
    # присваивания $editorState.SearchSource переключение фактически возвращалось к Steam.
    $editorState = [PSCustomObject]@{ SearchSource = 'Steam'; SwitchSerial = 0 }

    # Название и EXE используют один и тот же стиль ComboBox:
    # одинаковая высота строки, фон, рамка и выделение.
    $titleCandidates=@(); $titleCandidateMap=@{}

    $idLbl = New-Object System.Windows.Forms.Label; $idLbl.Text='App ID'; $idLbl.Location='697,14'; $idLbl.Size='55,28'; $idLbl.ForeColor=$steamUi.Muted; $idLbl.TextAlign=[System.Drawing.ContentAlignment]::MiddleLeft; $dlg.Controls.Add($idLbl)
    # Та же проблема и то же решение, что и у поля "Название" выше: однострочный
    # TextBox сам сжимает свою высоту под шрифт, поэтому рамку и фон рисует
    # Panel, а сам TextBox центрируется внутри неё вручную по вертикали.
    $pnlId = New-Object System.Windows.Forms.Panel
    $pnlId.Location='752,14'; $pnlId.Size='103,28'
    $pnlId.BackColor=$steamUi.Input; $pnlId.BorderStyle='FixedSingle'
    $dlg.Controls.Add($pnlId)

    $txtId = New-Object System.Windows.Forms.TextBox
    $txtId.AutoSize=$false
    # App ID: значение выравниваем по центру и горизонтально, и (за счёт
    # оборачивающей Panel) вертикально.
    $txtId.Multiline = $false
    $txtId.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
    $txtId.BackColor=$steamUi.Input; $txtId.ForeColor=$steamUi.Text; $txtId.BorderStyle='None'
    $pnlId.Controls.Add($txtId)
    $txtId.Width = $pnlId.ClientSize.Width - 10
    $txtId.Location = New-Object System.Drawing.Point(5, [int](($pnlId.ClientSize.Height - $txtId.PreferredHeight) / 2))

    $exeLbl = New-Object System.Windows.Forms.Label; $exeLbl.Text=(T 'card_launch'); $exeLbl.Location='20,50'; $exeLbl.Size='90,28'; $exeLbl.ForeColor=$steamUi.Muted; $exeLbl.TextAlign=[System.Drawing.ContentAlignment]::MiddleLeft; $dlg.Controls.Add($exeLbl)
    # Значок уверенности в выбранном EXE: зелёная галочка — файл определён
    # однозначно (совпал с уже сохранённым/кэшированным, единственный
    # кандидат, либо выбран пользователем вручную), красный "!" — программа
    # просто взяла первый файл из нескольких кандидатов наугад.
    $exeConfidenceBadge = New-ConfidenceBadge $dlg 91 55

    # Единый EXE-пикер для карточки и пакетного добавления.
    # В закрытом состоянии показывается только выбранный EXE.
    # Полный список раскрывается только по стрелке ComboBox.
    $cmbExe = New-Object SmartExeComboBox
    $cmbExe.Location = New-Object System.Drawing.Point(115,50)
    $cmbExe.Size = New-Object System.Drawing.Size(420,28)
    $cmbExe.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $cmbExe.DrawMode = [System.Windows.Forms.DrawMode]::OwnerDrawFixed
    $cmbExe.ItemHeight = 20
    $cmbExe.DropDownHeight = 128
    $cmbExe.IntegralHeight = $false
    $cmbExe.BackColor = $steamUi.Input
    $cmbExe.ForeColor = $steamUi.Text
    $cmbExe.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $cmbExe.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $dlg.Controls.Add($cmbExe)

    # Флаг отличает программное назначение выбора (первичное автоопределение,
    # где сама уверенность ещё вычисляется отдельно) от реального клика
    # пользователя по выпадающему списку — тот всегда означает осознанный
    # и потому "уверенный" выбор.
    $exeProgrammaticSelect = $false
    # БАГ-ФИКС: раньше подсказка exe из данных Steam применялась только ОДИН
    # РАЗ, в момент открытия карточки — с тем App ID, который автоматика
    # успела определить к этому моменту. Если автоматический поиск названия
    # не срабатывал (например, "Crash Bandicoot 4" на диске против
    # официального "Crash Bandicoot™ 4: It's About Time" в Steam — см. ниже
    # исправление самого поиска), а пользователь потом сам находил и
    # подтверждал игру вручную, exe так и оставался неопределённым (красный
    # "!"), хотя после подтверждения App ID подсказка от Steam уже могла
    # сработать. Флаг ExeConfirmed на $editorState (а не отдельная переменная —
    # присваивание простой переменной внутри вложенного обработчика события
    # не отражается на внешней области видимости) отслеживает, подтверждён ли
    # выбор exe (кэшем, сохранённым ярлыком, вручную пользователем или
    # подсказкой Steam), и используется, чтобы разрешить повторную попытку
    # подсказки при каждом новом подтверждении App ID, не перетирая уже
    # сделанный осознанный выбор.
    $editorState | Add-Member -NotePropertyName ExeConfirmed -NotePropertyValue $false -Force
    $cmbExe.Add_SelectedIndexChanged({
        if(-not $exeProgrammaticSelect){
            $editorState.ExeConfirmed = $true
            Set-ConfidenceBadge $exeConfidenceBadge $true (T 'badge_exe_manual') ''
        }
    })


    $cmbExe.Add_DrawItem({
        param($sender,$e)
        if($e.Index -lt 0){ return }
        $isSelected = (($e.State -band [System.Windows.Forms.DrawItemState]::Selected) -ne 0)
        $bg = if($isSelected){ $steamUi.Accent2 } else { $steamUi.Input }
        $fg = if($isSelected){ [System.Drawing.Color]::White } else { $steamUi.Text }
        $bgBrush = New-Object System.Drawing.SolidBrush($bg)
        $textBrush = New-Object System.Drawing.SolidBrush($fg)
        try {
            $e.Graphics.FillRectangle($bgBrush,$e.Bounds)
            $entry=$null
            try { $entry=$sender.Tag[$e.Index] } catch {}
            $text = if($entry -ne $null){ [string]$entry.Text } else { [string]$sender.Items[$e.Index] }
            $textX=$e.Bounds.X+8
            if($entry -ne $null -and $entry.Image -ne $null){
                $img=$entry.Image
                $iconSize=18
                $iy=$e.Bounds.Y+[Math]::Max(0,[int](($e.Bounds.Height-$iconSize)/2))
                $e.Graphics.DrawImage($img, $e.Bounds.X+4, $iy, $iconSize, $iconSize)
                $textX=$e.Bounds.X+30
            }
            # Иконку уже центрировали по Bounds.Height, а текст рядом рисовался с
            # жёстко зашитым отступом +2 от верха — то есть не по центру, а почти
            # у верхнего края строки. Меряем реальную высоту текста и центрируем
            # его так же, как иконку.
            $textSize = $e.Graphics.MeasureString($text, $sender.Font)
            $textY = $e.Bounds.Y + [Math]::Max(0, [int](($e.Bounds.Height - $textSize.Height) / 2))
            $e.Graphics.DrawString($text,$sender.Font,$textBrush,[float]$textX,[float]$textY)
        } finally {
            $bgBrush.Dispose(); $textBrush.Dispose()
        }
    })

    $btnBrowseExe = New-Object System.Windows.Forms.Button
    $btnBrowseExe.Text=(T 'browse')
    $btnBrowseExe.Location = New-Object System.Drawing.Point(540,49)
    $btnBrowseExe.Size = New-Object System.Drawing.Size(90,28)
    $btnBrowseExe.FlatStyle='Flat'; $btnBrowseExe.FlatAppearance.BorderColor=$steamUi.Border
    $btnBrowseExe.BackColor=$steamUi.Panel; $btnBrowseExe.ForeColor=$steamUi.Text
    $btnBrowseExe.Cursor=[System.Windows.Forms.Cursors]::Hand
    $dlg.Controls.Add($btnBrowseExe)

    $launchOptionsLbl = New-Object System.Windows.Forms.Label
    $launchOptionsLbl.Text=(T 'card_params'); $launchOptionsLbl.Location='20,87'; $launchOptionsLbl.Size='90,28'
    $launchOptionsLbl.ForeColor=$steamUi.Muted; $launchOptionsLbl.TextAlign=[System.Drawing.ContentAlignment]::MiddleLeft
    $dlg.Controls.Add($launchOptionsLbl)
    $launchOptionsLblTip = New-Object System.Windows.Forms.ToolTip
    $launchOptionsLblTip.SetToolTip($launchOptionsLbl, (T 'card_params_tip'))
    # Значок уверенности для параметров запуска — тот же приём, что и у
    # "Название"/"Запуск": зелёная галочка, когда выбранный вариант параметров
    # относится к уже выбранному EXE, красный "!" — когда относится к другому
    # файлу. До выбора варианта из списка остаётся скрытым.
    $launchOptConfidenceBadge = New-ConfidenceBadge $dlg 91 92

    # Поле параметров укорочено (было 740 шириной на всю строку), чтобы
    # справа поместилась короткая подсказка о том, что делает выбранный
    # вариант запуска. Отдельной кнопки-стрелки нет: список открывается тем
    # же способом, что и у поля "Название" — по клику/фокусу в самом поле,
    # без переключения на что-то отдельное.
    $pnlLaunchOptions = New-Object System.Windows.Forms.Panel
    $pnlLaunchOptions.Location='115,87'; $pnlLaunchOptions.Size='420,28'
    $pnlLaunchOptions.BackColor=$steamUi.Input; $pnlLaunchOptions.BorderStyle='FixedSingle'
    $dlg.Controls.Add($pnlLaunchOptions)

    $txtLaunchOptions = New-Object System.Windows.Forms.TextBox
    $txtLaunchOptions.AutoSize=$false; $txtLaunchOptions.BorderStyle='None'
    $txtLaunchOptions.BackColor=$steamUi.Input; $txtLaunchOptions.ForeColor=$steamUi.Text
    $txtLaunchOptions.Font=New-Object System.Drawing.Font('Consolas',8.8)
    $pnlLaunchOptions.Controls.Add($txtLaunchOptions)
    $txtLaunchOptions.Width=$pnlLaunchOptions.ClientSize.Width-10
    $txtLaunchOptions.Location=New-Object System.Drawing.Point(5,[int](($pnlLaunchOptions.ClientSize.Height-$txtLaunchOptions.PreferredHeight)/2))

    # Подсказка "что делает" появляется здесь только ПОСЛЕ выбора варианта
    # из списка — до этого остаётся пустой.
    $lblLaunchOptionsHint = New-Object System.Windows.Forms.Label
    $lblLaunchOptionsHint.Location = New-Object System.Drawing.Point(545,87)
    $lblLaunchOptionsHint.Size = New-Object System.Drawing.Size(310,28)
    $lblLaunchOptionsHint.ForeColor = $steamUi.Muted
    $lblLaunchOptionsHint.Font = New-Object System.Drawing.Font('Segoe UI',8)
    $lblLaunchOptionsHint.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $lblLaunchOptionsHint.AutoEllipsis = $true
    $lblLaunchOptionsHint.Text = ''
    $dlg.Controls.Add($lblLaunchOptionsHint)
    $launchOptionsHintTip = New-Object System.Windows.Forms.ToolTip

    # Выпадающий список вариантов — тот же приём, что и titleResults для
    # автодополнения названия: обычный ListBox, скрытый по умолчанию,
    # разворачивается поверх остальных контролов формы (BringToFront) на
    # время выбора. Реальные объекты вариантов (со Arguments/Description)
    # лежат в .Tag — сам список показывает только читаемые строки. Поле при
    # этом остаётся обычным текстовым полем — можно как выбрать вариант из
    # списка, так и просто напечатать свои параметры вручную.
    $launchOptResults = New-Object System.Windows.Forms.ListBox
    $launchOptResults.Location = New-Object System.Drawing.Point(115,116)
    $launchOptResults.Size = New-Object System.Drawing.Size(420,24)
    $launchOptResults.BackColor=$steamUi.Input; $launchOptResults.ForeColor=$steamUi.Text
    $launchOptResults.BorderStyle=[System.Windows.Forms.BorderStyle]::FixedSingle
    $launchOptResults.Font=New-Object System.Drawing.Font('Consolas',8.6)
    $launchOptResults.IntegralHeight=$false
    $launchOptResults.Visible=$false
    $launchOptResults.TabStop=$false
    $dlg.Controls.Add($launchOptResults)

    # Сдерживающий флаг на $editorState: без него Focus() на поле параметров
    # ниже сразу же заново открывал список, потому что вызывал тот же
    # обработчик GotFocus, что и обычный клик по полю — список просто не
    # успевал сворачиваться. Как и с ExeConfirmed выше, обычная переменная
    # тут не подойдёт: присваивание простой переменной внутри вложенного
    # обработчика события не отражается на внешней области видимости.
    $editorState | Add-Member -NotePropertyName LaunchOptSuppressReopen -NotePropertyValue $false -Force
    # Запись о том, к какому exe относится СЕЙЧАС выбранный вариант параметров
    # (если он вообще был выбран из списка, а не введён вручную). Хранится
    # отдельно от самой проверки, чтобы её можно было повторно прогнать при
    # смене EXE в "Запуск" — не только сразу после выбора параметров.
    $editorState | Add-Member -NotePropertyName LaunchOptExpectedEntry -NotePropertyValue $null -Force

    # Сверяет exe выбранного варианта параметров (если он есть) с реально
    # выбранным сейчас в "Запуск" и обновляет значок/подсказку у "Параметры".
    # Вызывается и сразу после выбора варианта, и при каждой последующей смене
    # EXE — иначе значок оставался бы в устаревшем состоянии.
    $updateLaunchOptExeMatch = {
        try {
            $picked = $editorState.LaunchOptExpectedEntry
            if ($picked -eq $null) { return }
            $expectedExeName = [string]$picked.Executable
            if (-not [string]::IsNullOrWhiteSpace($expectedExeName)) { $expectedExeName = [System.IO.Path]::GetFileName($expectedExeName) }
            $currentExeName = $null
            if ($cmbExe.SelectedIndex -ge 0 -and $cmbExe.SelectedIndex -lt $exeCandidates.Count) {
                try { $currentExeName = [System.IO.Path]::GetFileName([string]$exeCandidates[$cmbExe.SelectedIndex].FullName) } catch {}
            }
            $hintText = Format-LaunchOptionHint $picked
            $exeMismatch = (-not [string]::IsNullOrWhiteSpace($expectedExeName)) -and (-not [string]::IsNullOrWhiteSpace($currentExeName)) -and (-not [string]::Equals($expectedExeName, $currentExeName, [System.StringComparison]::OrdinalIgnoreCase))
            if ($exeMismatch) {
                $mismatchText = (T 'badge_opt_mismatch' @($expectedExeName, $currentExeName))
                Set-ConfidenceBadge $launchOptConfidenceBadge $false (T 'badge_opt_ok') $mismatchText
                $lblLaunchOptionsHint.Text = $mismatchText
                $launchOptionsHintTip.SetToolTip($lblLaunchOptionsHint, $mismatchText + ' ' + $hintText)
            } else {
                Set-ConfidenceBadge $launchOptConfidenceBadge $true (T 'badge_opt_ok') ''
                $lblLaunchOptionsHint.Text = $hintText
                $launchOptionsHintTip.SetToolTip($lblLaunchOptionsHint, $hintText)
            }
        } catch {}
    }
    # Ту же проверку нужно повторить, если после выбора параметров пользователь
    # сменил EXE в "Запуск" — иначе значок и подсказка остаются от прошлого EXE.
    $cmbExe.Add_SelectedIndexChanged({ & $updateLaunchOptExeMatch })

    $commitLaunchOptionResult = {
        try {
            if ($launchOptResults.SelectedIndex -lt 0) { return }
            $entries = $launchOptResults.Tag
            if ($entries -eq $null -or $launchOptResults.SelectedIndex -ge @($entries).Count) { return }
            $picked = @($entries)[$launchOptResults.SelectedIndex]
            $txtLaunchOptions.Text = [string]$picked.Arguments
            $txtLaunchOptions.SelectionStart = $txtLaunchOptions.Text.Length
            $txtLaunchOptions.SelectionLength = 0

            # Выбранный вариант параметров привязан к своему exe (Executable из
            # данных Steam). Если он не совпадает с уже выбранным в "Запуск"
            # файлом, отдельный значок уверенности у "Параметры" загорается
            # красным, а справа вместо расшифровки флагов появляется
            # предупреждение с названием правильного файла.
            $editorState.LaunchOptExpectedEntry = $picked
            & $updateLaunchOptExeMatch

            $launchOptResults.Visible = $false
            $launchOptResults.SelectedIndex = -1
            $editorState.LaunchOptSuppressReopen = $true
            $txtLaunchOptions.Focus()
        } catch {}
    }
    $launchOptResults.Add_MouseClick({ & $commitLaunchOptionResult })
    $launchOptResults.Add_KeyDown({
        if($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter){ $_.SuppressKeyPress=$true; & $commitLaunchOptionResult }
        elseif($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape){ $_.SuppressKeyPress=$true; $launchOptResults.Visible=$false; $launchOptResults.SelectedIndex=-1; $editorState.LaunchOptSuppressReopen=$true; $txtLaunchOptions.Focus() }
    })

    # Открывает список по клику/фокусу в самом поле параметров — как и в
    # поле "Название". Пункты без аргументов (Arguments пустая строка)
    # выбросили: выбрать такой пункт означало ничего не вписать в поле, то
    # есть по сути пустое действие, только засорявшее список.
    $openLaunchOptionsDropDown = {
        try {
            if ($editorState.LaunchOptSuppressReopen) {
                $editorState.LaunchOptSuppressReopen = $false
                return
            }
            $appIdForLookup = $txtId.Text.Trim()
            if ($appIdForLookup -notmatch '^\d+$') { return }
            if (-not $global:steamLaunchOptionsCache.ContainsKey($appIdForLookup)) {
                $status.Text = (T 'st_lo_search')
                [System.Windows.Forms.Application]::DoEvents()
            }
            $entries = @(Get-SteamDbLaunchOptions $appIdForLookup) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.Arguments) }
            if (@($entries).Count -eq 0) {
                $launchOptResults.Visible = $false
                $status.Text = (T 'st_lo_none')
                return
            }
            $status.Text = (T 'st_lo_found' @(@($entries).Count))
            $launchOptResults.Tag = $entries
            $launchOptResults.BeginUpdate()
            $launchOptResults.Items.Clear()
            foreach ($e in $entries) {
                [void]$launchOptResults.Items.Add( [string]$e.Arguments )
            }
            $launchOptResults.EndUpdate()
            $launchOptResults.SelectedIndex = -1
            $launchOptResults.Height = [Math]::Min(140, [Math]::Max(24, (@($entries).Count * 20) + 4))
            $launchOptResults.Visible = $true
            $launchOptResults.BringToFront()
        } catch {}
    }
    $txtLaunchOptions.Add_Click({ & $openLaunchOptionsDropDown })
    $txtLaunchOptions.Add_GotFocus({ & $openLaunchOptionsDropDown })
    $txtLaunchOptions.Add_KeyDown({
        if($_.KeyCode -eq [System.Windows.Forms.Keys]::Down -and $launchOptResults.Visible -and $launchOptResults.Items.Count -gt 0){
            $_.SuppressKeyPress=$true
            $launchOptResults.SelectedIndex=0
            $launchOptResults.Focus()
        } elseif($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape){
            $launchOptResults.Visible=$false; $launchOptResults.SelectedIndex=-1
        }
    })

    # Это поле напрямую записывается в shortcuts.vdf -> LaunchOptions.
    # Выпадающий список launchOptResults при открытии временно перекрывает
    # эту строку и верх обложек снизу (тот же приём, что и titleResults выше:
    # BringToFront поверх остальных контролов, пока список раскрыт) — это
    # нормально, он закрывается сразу после выбора варианта или по Esc.
    $status = New-Object System.Windows.Forms.Label; $status.Text=''; $status.Location='20,115'; $status.Size='850,20'; $status.ForeColor=$steamUi.Accent; $dlg.Controls.Add($status)

    $slots = [ordered]@{}
    $slots.Vertical = New-EditorCoverSlot $dlg (T 'slot_vertical') 20 138 270 280
    $slots.Horizontal = New-EditorCoverSlot $dlg (T 'slot_horizontal') 305 138 270 280
    $slots.Hero = New-EditorCoverSlot $dlg (T 'slot_hero') 590 138 270 280
    $slots.Logo = New-EditorCoverSlot $dlg (T 'slot_logo') 20 428 270 170

    # Клик по миниатюре открывает альтернативы ИМЕННО этого типа.
    # Если текущий источник Steam, варианты подгружаются напрямую из SGDB по
    # тому же Steam App ID — источник поиска карточки при этом НЕ переключается.
    $slots.Vertical.Picture.Add_Click({
        if($editorState.SearchSource -eq 'Steam' -and @($slots.Vertical.SgdbItems).Count -eq 0){
            [void](Prepare-EditorSteamSgdbAlternatives $slots.Vertical (T 'slot_vertical') $txtId.Text.Trim())
        }
        Show-EditorAlternativeCover $slots.Vertical (T 'slot_vertical')
    })
    $slots.Horizontal.Picture.Add_Click({
        if($editorState.SearchSource -eq 'Steam' -and @($slots.Horizontal.SgdbItems).Count -eq 0){
            [void](Prepare-EditorSteamSgdbAlternatives $slots.Horizontal (T 'slot_horizontal') $txtId.Text.Trim())
        }
        Show-EditorAlternativeCover $slots.Horizontal (T 'slot_horizontal')
    })
    $slots.Hero.Picture.Add_Click({
        if($editorState.SearchSource -eq 'Steam' -and @($slots.Hero.SgdbItems).Count -eq 0){
            [void](Prepare-EditorSteamSgdbAlternatives $slots.Hero (T 'slot_hero') $txtId.Text.Trim())
        }
        Show-EditorAlternativeCover $slots.Hero (T 'slot_hero')
    })
    $slots.Logo.Picture.Add_Click({
        if($editorState.SearchSource -eq 'Steam' -and @($slots.Logo.SgdbItems).Count -eq 0){
            [void](Prepare-EditorSteamSgdbAlternatives $slots.Logo (T 'slot_logo') $txtId.Text.Trim())
        }
        Show-EditorAlternativeCover $slots.Logo (T 'slot_logo')
    })

    $info = New-Object System.Windows.Forms.Label
    $info.Text=(T 'card_info')
    $info.Location='305,423'; $info.Size='555,70'; $info.ForeColor=$steamUi.Muted
    $dlg.Controls.Add($info)

    # Нижняя строка карточки. В пакетном режиме три кнопки стоят строго у нижнего
    # края окна и равномерно делят всю ширину карточки на три одинаковые части:
    # отменить пакет / пропустить текущую игру / добавить текущую игру.
    # В обычном режиме кнопки отмены нет: карточка закрывается крестиком окна,
    # а единственная нижняя кнопка занимает всю ширину.
    $bottomButtonY = $dlg.ClientSize.Height - 65
    $bottomButtonHeight = 50
    $bottomButtonGap = 10
    $bottomButtonWidth = [int](($dlg.ClientSize.Width - 40 - $bottomButtonGap*2) / 3)

    $btnAdd = New-Object System.Windows.Forms.Button
    $btnAdd.Text=if($editMode){(T 'card_save')}else{(T 'card_add')}
    if($batchMode){
        $btnAdd.Location=New-Object System.Drawing.Point((20 + ($bottomButtonWidth + $bottomButtonGap)*2),$bottomButtonY)
        $btnAdd.Size=New-Object System.Drawing.Size($bottomButtonWidth,$bottomButtonHeight)
    } else {
        $btnAdd.Location=New-Object System.Drawing.Point(20,$bottomButtonY)
        $btnAdd.Size=New-Object System.Drawing.Size(($dlg.ClientSize.Width - 40),$bottomButtonHeight)
    }
    $btnAdd.FlatStyle='Flat'; $btnAdd.FlatAppearance.BorderColor=$steamUi.Accent2; $btnAdd.BackColor=[System.Drawing.Color]::FromArgb(25,55,75); $btnAdd.ForeColor=$steamUi.Text; $btnAdd.Font=New-Object System.Drawing.Font('Segoe UI Semibold',10)
    $dlg.Controls.Add($btnAdd)

    $btnCancel = $null
    if($batchMode){
        $btnCancel = New-Object System.Windows.Forms.Button
        $btnCancel.Text=(T 'card_cancel')
        $btnCancel.Location=New-Object System.Drawing.Point(20,$bottomButtonY)
        $btnCancel.Size=New-Object System.Drawing.Size($bottomButtonWidth,$bottomButtonHeight)
        $btnCancel.FlatStyle='Flat'; $btnCancel.FlatAppearance.BorderColor=$steamUi.Border; $btnCancel.BackColor=$steamUi.Panel; $btnCancel.ForeColor=$steamUi.Text
        $dlg.Controls.Add($btnCancel)
    }

    $btnSkip = $null
    if($batchMode){
        $btnSkip = New-Object System.Windows.Forms.Button
        $btnSkip.Text=(T 'card_skip')
        $btnSkip.Location=New-Object System.Drawing.Point((20 + $bottomButtonWidth + $bottomButtonGap),$bottomButtonY)
        $btnSkip.Size=New-Object System.Drawing.Size($bottomButtonWidth,$bottomButtonHeight)
        $btnSkip.FlatStyle='Flat'
        $btnSkip.FlatAppearance.BorderColor=$steamUi.Border
        $btnSkip.BackColor=$steamUi.Panel
        $btnSkip.ForeColor=$steamUi.Text
        $btnSkip.Font=New-Object System.Drawing.Font('Segoe UI Semibold',10)
        $dlg.Controls.Add($btnSkip)
    }

    # ===== Кнопка региона (языка) обложек Steam — справа над нижней кнопкой =====
    # Показывает регион загруженных Steam-обложек (EN, РУ, DE…). По клику определяет,
    # на каких языках у игры есть обложки, и раскрывает список для выбора. Список —
    # обычный ListBox поверх формы (тот же приём, что у titleResults/launchOptResults).
    $btnCoverLang = New-Object System.Windows.Forms.Button
    $btnCoverLang.Name = 'EditorCoverLangButton'
    $btnCoverLang.Size = New-Object System.Drawing.Size(48,26)
    # Нижний край кнопки — вровень с нижним краем слота логотипа (Y=428, высота 170).
    $btnCoverLang.Location = New-Object System.Drawing.Point((860 - 48), ((428 + 170) - 26))
    $btnCoverLang.FlatStyle = 'Flat'
    $btnCoverLang.FlatAppearance.BorderColor = $steamUi.Border
    $btnCoverLang.BackColor = $steamUi.Panel
    $btnCoverLang.ForeColor = $steamUi.Text
    $btnCoverLang.Font = New-Object System.Drawing.Font('Segoe UI Semibold',8.5)
    $btnCoverLang.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnCoverLang.TabStop = $false
    $btnCoverLang.Tag = [PSCustomObject]@{ Lang='english'; Tip=(New-Object System.Windows.Forms.ToolTip) }
    $dlg.Controls.Add($btnCoverLang)
    Set-EditorCoverLangButton $btnCoverLang (Get-SteamAssetLanguage)

    $coverLangList = New-Object System.Windows.Forms.ListBox
    $coverLangList.BackColor = $steamUi.Input
    $coverLangList.ForeColor = $steamUi.Text
    $coverLangList.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $coverLangList.Font = New-Object System.Drawing.Font('Segoe UI',9)
    $coverLangList.IntegralHeight = $false
    $coverLangList.Visible = $false
    $coverLangList.TabStop = $false
    # Codes — Steam-имена языков в порядке строк списка; HiddenAt — когда список закрылся
    # (клик по кнопке при открытом списке сначала уводит с него фокус и закрывает его —
    # без этой отметки тот же клик тут же открыл бы список заново).
    $coverLangList.Tag = [PSCustomObject]@{ Codes=@(); HiddenAt=[datetime]::MinValue }
    $dlg.Controls.Add($coverLangList)

    $hideCoverLangList = {
        if($coverLangList.Visible){
            $coverLangList.Visible = $false
            $coverLangList.Tag.HiddenAt = [datetime]::Now
        }
    }

    $commitCoverLang = {
        $idx = $coverLangList.SelectedIndex
        $codes = @($coverLangList.Tag.Codes)
        & $hideCoverLangList
        if($idx -lt 0 -or $idx -ge $codes.Count){ return }
        $newLang = [string]$codes[$idx]
        if($newLang -eq [string]$btnCoverLang.Tag.Lang){ return }
        $appId = $txtId.Text.Trim()
        if($appId -notmatch '^\d+$'){ return }

        $addWas = $btnAdd.Enabled
        $btnCoverLang.Enabled = $false
        $btnAdd.Enabled = $false
        try {
            $n = [int]@(Reload-EditorSteamCoversForLanguage $appId $slots $status $newLang)[-1]
            if($n -gt 0){ Set-EditorCoverLangButton $btnCoverLang $newLang }
        } catch {
            $status.Text = (T 'covlang_fail' @([string](Get-SteamLanguageInfo $newLang).Name))
        } finally {
            $btnAdd.Enabled = $addWas
            $btnCoverLang.Enabled = ($editorState.SearchSource -eq 'Steam')
        }
    }

    $coverLangList.Add_MouseClick({
        $i = $coverLangList.IndexFromPoint($_.Location)
        if($i -lt 0){ return }
        $coverLangList.SelectedIndex = $i
        & $commitCoverLang
    })
    $coverLangList.Add_KeyDown({
        if($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter){ $_.SuppressKeyPress = $true; $_.Handled = $true; & $commitCoverLang }
        elseif($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape){ $_.SuppressKeyPress = $true; $_.Handled = $true; & $hideCoverLangList }
    })
    $coverLangList.Add_Leave({ & $hideCoverLangList })

    $btnCoverLang.Add_Click({
        if($coverLangList.Visible){ & $hideCoverLangList; return }
        if(((Get-Date) - $coverLangList.Tag.HiddenAt).TotalMilliseconds -lt 300){ return }
        if($editorState.SearchSource -ne 'Steam'){ return }
        $appId = $txtId.Text.Trim()
        if($appId -notmatch '^\d+$'){ $status.Text = (T 'covlang_no_appid'); return }

        $status.Text = (T 'covlang_checking')
        $btnCoverLang.Enabled = $false
        $dlg.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $avail = @()
        $pumpWas = $global:uiPumpDuringDownload
        $global:uiPumpDuringDownload = $true
        try { $avail = @(Get-SteamPicsAvailableLanguages $appId) } catch { $avail = @() }
        finally {
            $global:uiPumpDuringDownload = $pumpWas
            $dlg.Cursor = [System.Windows.Forms.Cursors]::Default
            $btnCoverLang.Enabled = ($editorState.SearchSource -eq 'Steam')
        }

        $cur = [string]$btnCoverLang.Tag.Lang
        if($avail.Count -eq 0){ $status.Text = (T 'covlang_unavailable'); return }
        $codes = @($avail)
        if($codes -notcontains $cur){ $codes = @($cur) + $codes }
        if($codes.Count -le 1){ $status.Text = (T 'covlang_only_one' @([string](Get-SteamLanguageInfo $cur).Name)); return }

        $coverLangList.Items.Clear()
        foreach($c in $codes){
            $inf = Get-SteamLanguageInfo $c
            [void]$coverLangList.Items.Add(('{0}  ({1})' -f $inf.Name, $inf.Short))
        }
        $coverLangList.Tag.Codes = $codes
        $listW = 210
        $listH = [Math]::Min(240, ([int]$coverLangList.ItemHeight * $codes.Count) + 6)
        $coverLangList.Size = New-Object System.Drawing.Size($listW, $listH)
        $coverLangList.Location = New-Object System.Drawing.Point(($btnCoverLang.Right - $listW), ($btnCoverLang.Top - $listH - 2))
        $coverLangList.SelectedIndex = [Array]::IndexOf($codes, $cur)
        $status.Text = (T 'covlang_pick')
        $coverLangList.Visible = $true
        $coverLangList.BringToFront()
        $coverLangList.Focus() | Out-Null
    })

    $updateSearchSourceUi = {
        # Регион обложек относится только к Steam-обложкам.
        try { $btnCoverLang.Enabled = ($editorState.SearchSource -eq 'Steam'); if($editorState.SearchSource -ne 'Steam'){ $coverLangList.Visible = $false } } catch {}
        if($editorState.SearchSource -eq 'Steam'){
            $searchSteamBtn.BackColor=$steamUi.Accent2; $searchSteamBtn.ForeColor=[System.Drawing.Color]::White
            $searchSteamBtn.FlatAppearance.BorderColor=$steamUi.Accent2
            $idLbl.Text='App ID'
        } else {
            $searchSgdbBtn.BackColor=$steamUi.Accent2; $searchSgdbBtn.ForeColor=[System.Drawing.Color]::White
            $searchSgdbBtn.FlatAppearance.BorderColor=$steamUi.Accent2
            $searchSteamBtn.BackColor=$steamUi.Panel; $searchSteamBtn.ForeColor=$steamUi.Muted
            $searchSteamBtn.FlatAppearance.BorderColor=$steamUi.Border
            $idLbl.Text='SGDB ID'
        }
        & $updateSgdbButtonState
        if($editorState.SearchSource -eq 'SteamGridDB' -and $searchSgdbBtn.Enabled){
            $searchSgdbBtn.BackColor=$steamUi.Accent2
            $searchSgdbBtn.ForeColor=[System.Drawing.Color]::White
            $searchSgdbBtn.FlatAppearance.BorderColor=$steamUi.Accent2
        }
        # Значок яркий только у активного источника; у неактивного и у
        # заблокированной SGDB-кнопки — приглушённый.
        try {
            $steamActive = ($editorState.SearchSource -eq 'Steam')
            $sgdbActive = (($editorState.SearchSource -eq 'SteamGridDB') -and $searchSgdbBtn.Enabled)
            if ($searchSteamBtn.Tag -ne $null) { $searchSteamBtn.Image = $(if($steamActive){ $searchSteamBtn.Tag.Bright } else { $searchSteamBtn.Tag.Dim }) }
            if ($searchSgdbBtn.Tag -ne $null) { $searchSgdbBtn.Image = $(if($sgdbActive){ $searchSgdbBtn.Tag.Bright } else { $searchSgdbBtn.Tag.Dim }) }
        } catch {}
    }
    & $updateSearchSourceUi

    # Переключение источника поиска.
    # Важно: сетевой поиск НЕ запускается прямо из Click-обработчика.
    # Он ставится в очередь UI через BeginInvoke. Это исключает повторный вход
    # в обработчик кнопки через Application.DoEvents() и устраняет ситуацию,
    # когда SGDB-поиск продолжает выполняться поверх нового Steam-поиска.
    # Пока текущий поиск выполняется, обе кнопки источника заблокированы.
    # После завершения их можно снова переключать.
    # Переключение источника поиска.
    # ВАЖНО: поиск выполняется непосредственно после смены источника в том же
    # UI-обработчике. Здесь намеренно НЕТ BeginInvoke/DoEvents вокруг самого
    # поиска: предыдущая схема могла оставить карточку в промежуточном
    # состоянии «ищу…», а следующий источник уже не получал результат.
    # Каждый клик запускает полностью самостоятельный поиск и загрузку.
    $switchSearchSource = {
        param([string]$newSource)

        if($editorState.SearchSource -eq $newSource){ return }

        $editorState.SwitchSerial = [int]$editorState.SwitchSerial + 1
        $serial = [int]$editorState.SwitchSerial
        $editorState.SearchSource = $newSource

        try { $titleResults.Visible=$false } catch {}
        try { $dlg.ActiveControl=$null } catch {}
        & $updateSearchSourceUi

        $query = ([string]$txtTitle.Text).Trim()
        $txtId.Text = ''

        # Сбрасываем старые варианты названия и старые миниатюры.
        $tag=$txtTitle.Tag
        if($tag -ne $null){
            $tag.RefreshNeeded=$true
            $tag.Busy=$false
            $tag.Map=@{}
        }
        try { $titleResults.Items.Clear() } catch {}
        foreach($sl in $slots.Values){
            try { Set-EditorPreviewFile $sl $null | Out-Null } catch {}
            try { $sl.ExpectedSource=$newSource } catch {}
            try { $sl.SgdbItems=@() } catch {}
        }

        if([string]::IsNullOrWhiteSpace($query) -or $query.Length -lt 2){
            $status.Text=if($newSource -eq 'Steam'){(T 'st_name_needed_steam')}else{(T 'st_name_needed_sgdb')}
            return
        }

        $searchSteamBtn.Enabled=$false
        $searchSgdbBtn.Enabled=$false
        $btnAdd.Enabled=$false
        $status.Text=if($newSource -eq 'Steam'){(T 'st_searching_steam')}else{(T 'st_searching_sgdb')}
        [System.Windows.Forms.Application]::DoEvents()

        try {
            # Если между началом и концом поиска был создан новый запрос,
            # результат старого запроса не имеет права менять карточку.
            if([int]$editorState.SwitchSerial -ne $serial){ return }

            $candidates=@()
            $chosen=$null

            if($newSource -eq 'Steam'){
                # Собственный поиск вариантов Steam — без SGDB и без ключа.
                # Каждый вариант уже несёт настоящий Steam App ID.
                try { $candidates=@(Get-SteamStoreNameCandidates $query) } catch { $candidates=@() }
                if(@($candidates).Count -gt 0){
                    $chosen=$candidates[0]
                } else {
                    try { $chosen=Find-SteamAppInfo $query } catch { $chosen=$null }
                }
            } else {
                try { $candidates=@(Get-EditorSgdbCandidates $query '') } catch { $candidates=@() }
                if(@($candidates).Count -gt 0){ $chosen=$candidates[0] }
            }

            if([int]$editorState.SwitchSerial -ne $serial){ return }

            if($null -eq $chosen){
                $status.Text=if($newSource -eq 'Steam'){(T 'st_notfound_steam')}else{(T 'st_notfound_sgdb')}
                return
            }

            $chosenId=0
            try { $chosenId=[int]$chosen.Id } catch { $chosenId=0 }
            if($chosenId -le 0){
                $status.Text=if($newSource -eq 'Steam'){(T 'st_noid_steam')}else{(T 'st_noid_sgdb')}
                return
            }

            # Заполняем выпадающий список теми же кандидатами, которые реально
            # использованы для текущего источника.
            if($tag -ne $null){
                $newMap=@{}
                foreach($c in $candidates){
                    if($null -eq $c){continue}
                    $nm=[string]$c.Name
                    if(-not [string]::IsNullOrWhiteSpace($nm) -and -not $newMap.ContainsKey($nm)){
                        $newMap[$nm]=$c
                    }
                }
                if($newMap.Count -eq 0){ $newMap[[string]$chosen.Name]=$chosen }
                $tag.Map=$newMap
                $tag.RefreshNeeded=$false

                # Переключение источника должно сразу подготовить тот же список,
                # который используется после ручного Enter/автопоиска.
                try {
                    $titleResults.BeginUpdate()
                    $titleResults.Items.Clear()
                    foreach($key in $newMap.Keys){ [void]$titleResults.Items.Add([string]$key) }
                    & $resizeEditorTitleResults
                } finally {
                    try { $titleResults.EndUpdate() } catch {}
                }
                $titleResults.SelectedIndex=-1
            }

            $txtTitle.Text=[string]$chosen.Name
            $txtTitle.SelectionStart=$txtTitle.Text.Length
            $txtId.Text=[string]$chosenId

            if([int]$editorState.SwitchSerial -ne $serial){ return }

            # Ключевой момент: оба источника запускают свои собственные
            # загрузчики. После возврата с SGDB Steam снова проходит именно
            # Load-EditorSteamPreviews, а SGDB — только Load-EditorSgdbPreviews.
            if($newSource -eq 'Steam'){
                Load-EditorSteamPreviews ([string]$chosenId) $slots $status
            } else {
                [void](Load-EditorSgdbPreviews -gameName $txtTitle.Text.Trim() -steamAppId '' -slots $slots -statusLabel $status -sgdbGameId $chosenId)
            }
        }
        catch {
            if([int]$editorState.SwitchSerial -eq $serial){
                foreach($sl in $slots.Values){ try { Set-EditorPreviewFile $sl $null | Out-Null } catch {} }
                $status.Text=(T 'st_src_error' @($newSource, [string]$_.Exception.Message))
            }
        }
        finally {
            if([int]$editorState.SwitchSerial -eq $serial){
                $searchSteamBtn.Enabled=$true
                & $updateSearchSourceUi
                $btnAdd.Enabled=$true
                Set-ConfidenceBadge $titleConfidenceBadge ($txtId.Text.Trim() -match '^\d+$') (T 'badge_title_ok') (T 'badge_title_fail_src')
            }
        }
    }

    $searchSteamBtn.Add_Click({ & $switchSearchSource 'Steam' })
    $searchSgdbBtn.Add_Click({ & $switchSearchSource 'SteamGridDB' })

    # ВАЖНО: $exeCandidates раньше был обычным PS-массивом, и добавление через
    # "$exeCandidates += $x" создавало НОВЫЙ объект массива и переприсваивало
    # переменную. Разные обработчики событий (Add_Click, SelectedIndexChanged,
    # кнопка "Сохранить" и т.д.) замыкают СВОИ копии этой переменной на момент
    # создания диалога, поэтому переприсваивание в одном обработчике не было
    # видно остальным — новый EXE попадал в cmbExe.Items (это общий .NET-объект),
    # но не попадал в "чужие" копии $exeCandidates, из-за чего индекс/выбор/сохранение
    # расходились с реальным списком. List[object] мутируется на месте через
    # .Add(), а не переприсваивается, поэтому все обработчики видят один и тот
    # же объект и одни и те же добавленные элементы.
    [System.Collections.Generic.List[object]]$exeCandidates = @(Get-EditorExecutableCandidates $gamePath)
    $cmbExe.Items.Clear()
    $exeDisplay = New-Object System.Collections.Generic.List[object]
    for($i=0; $i -lt $exeCandidates.Count; $i++) {
        $exe = $exeCandidates[$i]
        if($null -eq $exe){ continue }
        $rel = [string]$exe.FullName
        try {
            if($exe.FullName.StartsWith($gamePath, [System.StringComparison]::OrdinalIgnoreCase)) {
                $rel = $exe.FullName.Substring($gamePath.Length).TrimStart('\')
            } else { $rel = [System.IO.Path]::GetFileName($exe.FullName) }
        } catch {}
        $ico = $null
        try { $ico=[System.Drawing.Icon]::ExtractAssociatedIcon($exe.FullName) } catch {}
        $entry=[PSCustomObject]@{ Text=$rel; Image=$ico }
        [void]$exeDisplay.Add($entry)
        [void]$cmbExe.Items.Add($rel)
    }
    if($editMode -and $existingShortcut -ne $null){
        $existingExePath=[string]$existingShortcut.Exe
        $existingLaunchOptions=[string]$existingShortcut.LaunchOptions
        if($existingLaunchOptions){$txtLaunchOptions.Text=$existingLaunchOptions}
        if($existingExePath -and (Test-Path $existingExePath)){
            $existingExeItem=Get-Item -LiteralPath $existingExePath -ErrorAction SilentlyContinue
            if($existingExeItem -ne $null){
                $foundExistingIndex=-1
                for($i=0;$i -lt $exeCandidates.Count;$i++){
                    try{if([string]::Equals([string]$exeCandidates[$i].FullName,[string]$existingExeItem.FullName,[System.StringComparison]::OrdinalIgnoreCase)){$foundExistingIndex=$i;break}}catch{}
                }
                if($foundExistingIndex -lt 0){
                    $exeCandidates.Add($existingExeItem)
                    $relExisting=[string]$existingExeItem.FullName
                    try{if($existingExeItem.FullName.StartsWith($gamePath,[System.StringComparison]::OrdinalIgnoreCase)){$relExisting=$existingExeItem.FullName.Substring($gamePath.Length).TrimStart('\')}}catch{}
                    $icoExisting=$null; try{$icoExisting=[System.Drawing.Icon]::ExtractAssociatedIcon($existingExeItem.FullName)}catch{}
                    [void]$exeDisplay.Add([PSCustomObject]@{Text=$relExisting;Image=$icoExisting})
                    [void]$cmbExe.Items.Add($relExisting)
                    $foundExistingIndex=$exeCandidates.Count-1
                }
                try{$global:exeSelectionCache[$gamePath.ToUpper()]=[string]$existingExeItem.FullName}catch{}
            }
        }
    }

    $cmbExe.Tag = $exeDisplay.ToArray()
    $cmbExe.DropDownHeight = 128
    $cmbExe.IntegralHeight = $false

    $selectEditorExe = {
        param($index)
        if($index -lt 0 -or $index -ge $exeCandidates.Count -or $cmbExe.Items.Count -eq 0){ return }
        $cmbExe.SelectedIndex = $index
        try { $status.Text = (T 'st_exe_selected' @([string]$cmbExe.Items[$index])) } catch {}
    }

    if($cmbExe.Items.Count -gt 0){
        $cacheKey = $gamePath.ToUpper()
        $cached = $null
        try { if($global:exeSelectionCache.ContainsKey($cacheKey)){ $cached=[string]$global:exeSelectionCache[$cacheKey] } } catch {}
        $idx = -1
        if($cached){
            for($i=0; $i -lt $exeCandidates.Count; $i++){
                try {
                    if([string]::Equals([string]$exeCandidates[$i].FullName,$cached,[System.StringComparison]::OrdinalIgnoreCase)){ $idx=$i; break }
                } catch {}
            }
        }
        if($editMode -and $existingShortcut -ne $null -and $existingShortcut.Exe){
            for($i=0;$i -lt $exeCandidates.Count;$i++){
                try{if([string]::Equals([string]$exeCandidates[$i].FullName,[string]$existingShortcut.Exe,[System.StringComparison]::OrdinalIgnoreCase)){$idx=$i;break}}catch{}
            }
        }
        # Уверенность фиксируем ДО подстановки запасного индекса 0: если ни кэш,
        # ни уже сохранённый ярлык не дали совпадения среди нескольких
        # кандидатов, это угадывание, а не определённый выбор.
        $exeConfidentInitial = ($idx -ge 0) -or ($exeCandidates.Count -le 1)
        $editorState.ExeConfirmed = $exeConfidentInitial
        if($idx -lt 0){ $idx=0 }
        $exeProgrammaticSelect = $true
        try { & $selectEditorExe $idx } finally { $exeProgrammaticSelect = $false }
        Set-ConfidenceBadge $exeConfidenceBadge $exeConfidentInitial (T 'badge_exe_ok') (T 'badge_exe_multi')
    } else {
        $status.Text=(T 'st_no_exe')
        Set-ConfidenceBadge $exeConfidenceBadge $false (T 'badge_exe_ok') (T 'badge_exe_none')
    }

    $btnBrowseExe.Add_Click({
        try {
            # Ручной выбор допускает EXE и BAT, но принимать можно только файл
            # из папки самой игры или одной из её подпапок.
            while($true){
                $ofd = New-Object System.Windows.Forms.OpenFileDialog
                $ofd.Title = (T 'ofd_title')
                $ofd.Filter = (T 'ofd_filter')
                $ofd.CheckFileExists = $true
                $ofd.Multiselect = $false
                try {
                    if($cmbExe.SelectedIndex -ge 0){
                        $selectedExe=$exeCandidates[$cmbExe.SelectedIndex]
                        if($selectedExe -and (Test-Path $selectedExe.FullName)){ $ofd.InitialDirectory=$selectedExe.DirectoryName }
                    } elseif(Test-Path $gamePath) { $ofd.InitialDirectory=$gamePath }
                } catch {}

                if($ofd.ShowDialog($dlg) -ne [System.Windows.Forms.DialogResult]::OK){ break }
                $chosenExe=Get-Item -LiteralPath $ofd.FileName -ErrorAction SilentlyContinue
                if($chosenExe -eq $null){ break }

                if(-not (Test-FileInsideRoot $chosenExe.FullName $gamePath)){
                    [System.Windows.Forms.MessageBox]::Show($dlg,
                        (T 'exe_outside') + "`r`n`r`n" + [string]$gamePath,
                        (T 'exe_outside_title'),
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
                    continue
                }

                $existingIndex=-1
                for($i=0;$i -lt $exeCandidates.Count;$i++){
                    try { if([string]::Equals([string]$exeCandidates[$i].FullName,[string]$chosenExe.FullName,[System.StringComparison]::OrdinalIgnoreCase)){ $existingIndex=$i; break } } catch {}
                }
                if($existingIndex -lt 0){
                    $exeCandidates.Add($chosenExe)
                    $existingIndex=$exeCandidates.Count-1
                    $rel=[string]$chosenExe.FullName
                    try { $rel=$chosenExe.FullName.Substring(([System.IO.Path]::GetFullPath($gamePath)).TrimEnd('\').Length).TrimStart('\') } catch {}
                    $ico = $null
                    try { $ico=[System.Drawing.Icon]::ExtractAssociatedIcon($chosenExe.FullName) } catch {}
                    $entry=[PSCustomObject]@{ Text=$rel; Image=$ico }
                    $exeDisplay.Add($entry)
                    $cmbExe.Tag = $exeDisplay.ToArray()
                    [void]$cmbExe.Items.Add($rel)
                }
                # ВАЖНО: после ручного добавления элемент должен стать выбранным
                # сразу, а не просто появиться в выпадающем списке. В некоторых
                # случаях OwnerDraw ComboBox после Items.Add сохраняет старый
                # SelectedIndex, поэтому задаём выбор повторно и через SelectedItem.
                try {
                    $cmbExe.SelectedIndex = -1
                    $cmbExe.SelectedIndex = $existingIndex
                    if ($existingIndex -ge 0 -and $existingIndex -lt $cmbExe.Items.Count) {
                        $cmbExe.SelectedItem = $cmbExe.Items[$existingIndex]
                    }
                    $cmbExe.Refresh()
                } catch {}
                & $selectEditorExe $existingIndex
                try {
                    $global:exeSelectionCache[$gamePath.ToUpper()]=[string]$chosenExe.FullName
                } catch {}
                break
            }
        } catch {}
    })

    # Название — отдельный TextBox. Варианты получаем в отдельном ComboBox-popup.
    # Нативный WinForms AutoComplete здесь намеренно отключён:
    # при динамической замене Items он может одновременно держать свой
    # внутренний список и вызывать DropDown/WM_NOTIFY. Это и было причиной
    # вылета при ручной правке названия.
    $txtTitle.Tag=[PSCustomObject]@{Busy=$false;Map=@{};RefreshNeeded=$true;SuppressAutoSearch=$false;SearchTimer=$null}

    function Update-EditorTitleCandidates {
        try {
            $tag=$txtTitle.Tag
            if($null -eq $tag -or $tag.Busy){return $false}

            $query=([string]$txtTitle.Text).Trim()
            if($query.Length -lt 2){
                try { $titleResults.Items.Clear() } catch {}
                return $false
            }

            if(-not $tag.RefreshNeeded -and $titleResults.Items.Count -gt 0){return $true}

            $tag.Busy=$true
            try {
                if($editorState.SearchSource -eq 'Steam') {
                    # Собственный поиск вариантов Steam — без SGDB и без ключа.
                    # Каждый вариант уже несёт настоящий Steam App ID, который
                    # используется напрямую при выборе варианта из списка.
                    $candidates=@(Get-SteamStoreNameCandidates $query)
                } else {
                    $candidates=@(Get-EditorSgdbCandidates $query $txtId.Text.Trim())
                }

                $newMap=@{}
                $names=New-Object System.Collections.Generic.List[string]
                foreach($c in $candidates){
                    if($null -eq $c){continue}
                    $nm=[string]$c.Name
                    if([string]::IsNullOrWhiteSpace($nm)){continue}
                    if(-not $newMap.ContainsKey($nm)){
                        $newMap[$nm]=$c
                        [void]$names.Add($nm)
                    }
                }

                # Это отдельный TextBox, поэтому обновление Items списка
                # НИКОГДА не должно переписывать Text. Раньше здесь использовался
                # .Trim() -> возврат строки в Text, из-за чего введённый пробел
                # в конце названия сразу исчезал.
                $tag.SuppressAutoSearch=$true
                try {
                    try { $titleResults.Visible=$false } catch {}

                    $titleResults.BeginUpdate()
                    try {
                        $titleResults.Items.Clear()
                        foreach($nm in $names){ [void]$titleResults.Items.Add($nm) }
                        & $resizeEditorTitleResults
                    } finally {
                        $titleResults.EndUpdate()
                    }
                    $titleResults.SelectedIndex=-1
                    $titleResults.Visible=$false
                } finally {
                    $tag.SuppressAutoSearch=$false
                }

                $tag.Map=$newMap
                $tag.RefreshNeeded=$false
                return ($names.Count -gt 0)
            } finally {
                $tag.Busy=$false
            }
        } catch {
            try { $titleResults.EndUpdate() } catch {}
            try { $txtTitle.Tag.Busy=$false } catch {}
            return $false
        }
    }

    # Поиск запускается с небольшой задержкой после окончания ввода.
    # Это даёт Steam Store-поиску работать как автоподсказки, но без сетевого
    # запроса на каждый символ и без реэнтерантного DropDown-события.
    $titleSearchTimer=New-Object System.Windows.Forms.Timer
    $titleSearchTimer.Interval=350
    $titleSearchTimer.Add_Tick({
        try {
            try { $txtTitle.Tag.SearchTimer.Stop() } catch {}
            $tag=$txtTitle.Tag
            if($null -eq $tag -or $tag.Busy -or $tag.SuppressAutoSearch){return}
            $query=([string]$txtTitle.Text).Trim()
            if($query.Length -lt 2){return}

            $hasItems=Update-EditorTitleCandidates
            if($hasItems -and $txtTitle.Focused -and $titleResults.Items.Count -gt 0){
                try { & $openEditorTitleDropDown } catch {}
            }
        } catch {
            try { $txtTitle.Tag.SearchTimer.Stop() } catch {}
        }
    })
    $txtTitle.Tag.SearchTimer=$titleSearchTimer

    $queueEditorTitleSearch={
        try {
            $tag=$txtTitle.Tag
            if($null -eq $tag -or $tag.Busy -or $tag.SuppressAutoSearch){return}
            $tag.RefreshNeeded=$true
            $timer=$tag.SearchTimer
            if($null -eq $timer){ return }
            $timer.Stop()
            $timer.Start()
        } catch {}
    }

    # Открываем список НЕ внутри KeyDown/Timer-события, а через очередь UI.
    # WinForms ComboBox иногда игнорирует DroppedDown=$true, пока ещё
    # обрабатывает Enter/WM_KEYDOWN. BeginInvoke гарантирует, что список
    # раскроется уже после завершения текущего события.
    $openEditorTitleDropDown = {
        try {
            $tag=$txtTitle.Tag
            if($null -eq $tag -or $tag.Busy -or $tag.SuppressAutoSearch){ return }
            if($titleResults.Items.Count -le 0 -or -not $txtTitle.Focused){ return }
            $titleResults.SelectedIndex=-1
            $titleResults.Visible=$true
            $titleResults.BringToFront()
            # Открываем список результатов поверх остальных контролов формы. TextBox остаётся
            # отдельным полем ввода и поэтому его Text никогда не меняется от
            # обновления Items.
        } catch {}
    }

    $closeEditorTitleDropDown = {
        try { $titleResults.Visible=$false; $titleResults.SelectedIndex=-1; $txtTitle.Focus() } catch {}
    }


    # Выбор результата — единственная операция, которая имеет право менять
    # название и ID. Сам поиск, обновление списка и набор текста этого не делают.
    $commitEditorTitleResult = {
        try {
            $tag=$txtTitle.Tag
            if($null -eq $tag -or $tag.Busy){return}
            $nm=[string]$titleResults.SelectedItem
            if([string]::IsNullOrWhiteSpace($nm)){return}
            if($null -eq $tag.Map -or -not $tag.Map.ContainsKey($nm)){return}

            $choice=$tag.Map[$nm]

            try { $tag.SearchTimer.Stop() } catch {}
            $tag.Busy=$true
            $tag.SuppressAutoSearch=$true
            try {
                & $closeEditorTitleDropDown
                # Текст выбранного SGDB-варианта становится новым точным названием.
                # При источнике Steam SGDB-ID НЕ записываем в поле App ID: вместо
                # этого по полному названию ищем соответствующую игру в Steam.
                $txtTitle.Text=[string]$choice.Name
                $txtTitle.SelectionStart=$txtTitle.Text.Length
                $txtTitle.SelectionLength=0
                $tag.RefreshNeeded=$false
            } finally {
                $tag.SuppressAutoSearch=$false
                $tag.Busy=$false
            }

            $searchSteamBtn.Enabled=$false
            $searchSgdbBtn.Enabled=$false
            $btnAdd.Enabled=$false
            try {
                if($editorState.SearchSource -eq 'Steam') {
                    # Выбранный вариант уже несёт настоящий Steam App ID (из
                    # собственного поиска Steam) — повторный поиск не нужен.
                    $steamChosenId=0
                    try { $steamChosenId=[int]$choice.Id } catch { $steamChosenId=0 }
                    if($steamChosenId -gt 0){
                        $txtId.Text=[string]$steamChosenId
                        Load-EditorSteamPreviews ([string]$steamChosenId) $slots $status
                        & $tryApplySteamExeHint ([string]$steamChosenId)
                    } else {
                        $txtId.Text=''
                        foreach($sl in $slots.Values){ try { Set-EditorPreviewFile $sl $null | Out-Null } catch {} }
                        $status.Text=(T 'st_pick_noid_steam')
                    }
                } else {
                    $chosenId=0
                    try { $chosenId=[int]$choice.Id } catch {}
                    if($chosenId -le 0){ throw (T 'err_pick_noid_sgdb') }
                    $txtId.Text=[string]$chosenId
                    [void](Load-EditorSgdbPreviews -gameName $txtTitle.Text.Trim() -steamAppId '' -slots $slots -statusLabel $status -sgdbGameId $chosenId)
                }
            } catch {
                $status.Text=$editorState.SearchSource+': '+[string]$_.Exception.Message
            } finally {
                $searchSteamBtn.Enabled=$true
                & $updateSearchSourceUi
                $btnAdd.Enabled=$true
                Set-ConfidenceBadge $titleConfidenceBadge ($txtId.Text.Trim() -match '^\d+$') (T 'badge_title_ok') (T 'badge_title_fail_pick')
            }
        } catch {}
    }

    $txtTitle.Add_TextChanged({
        try {
            $tag=$txtTitle.Tag
            if($tag -ne $null -and -not $tag.Busy -and -not $tag.SuppressAutoSearch){
                & $queueEditorTitleSearch
                # Ручная правка текста делает прежнее подтверждение неактуальным,
                # пока новый поиск/выбор его не подтвердит заново.
                Set-ConfidenceBadge $titleConfidenceBadge $false (T 'badge_title_ok') (T 'badge_title_manual')
            }
        } catch {}
    })

    
    $titleResults.Add_MouseClick({ & $commitEditorTitleResult })
    $titleResults.Add_KeyDown({
        if($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter){ $_.SuppressKeyPress=$true; & $commitEditorTitleResult }
        elseif($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape){ $_.SuppressKeyPress=$true; & $closeEditorTitleDropDown; $txtTitle.Focus() }
    })

    $txtTitle.Add_KeyDown({
        if($_.KeyCode -eq [System.Windows.Forms.Keys]::Down -and $titleResults.Visible -and $titleResults.Items.Count -gt 0){
            $_.SuppressKeyPress=$true
            $titleResults.SelectedIndex=0
            $titleResults.Focus()
            return
        }
        if($_.KeyCode -ne [System.Windows.Forms.Keys]::Enter){
            try { & $queueEditorTitleSearch } catch {}
            return
        }
        $_.SuppressKeyPress=$true
        $name=$txtTitle.Text.Trim()
        if([string]::IsNullOrWhiteSpace($name)){return}
        try { $txtTitle.Tag.SearchTimer.Stop() } catch {}
        try { & $closeEditorTitleDropDown } catch {}
        $txtTitle.Focus()

        if($editorState.SearchSource -eq 'Steam') {
            # Enter в поле «Название» должен повторно искать игру в Steam по
            # введённому тексту — точно так же, как при открытии карточки —
            # а не просто обновлять список подсказок SGDB. Раньше Enter вызывал
            # только Update-EditorTitleCandidates: если список подсказок уже
            # был открыт с теми же вариантами (например, при том же названии),
            # видимых изменений не происходило и казалось, что Enter не работает.
            $searchSteamBtn.Enabled=$false
            $searchSgdbBtn.Enabled=$false
            $btnAdd.Enabled=$false
            $status.Text=(T 'st_searching_name_steam' @($name))
            [System.Windows.Forms.Application]::DoEvents()
            try {
                $steamFound=$null
                try { $steamFound=Find-SteamAppInfo $name } catch { $steamFound=$null }
                if($steamFound -ne $null){
                    $txtId.Text=[string]$steamFound.Id
                    if(-not [string]::IsNullOrWhiteSpace([string]$steamFound.Name)){
                        $tag=$txtTitle.Tag
                        if($tag -ne $null){ $tag.SuppressAutoSearch=$true }
                        try {
                            $txtTitle.Text=[string]$steamFound.Name
                            $txtTitle.SelectionStart=$txtTitle.Text.Length
                            $txtTitle.SelectionLength=0
                        } finally {
                            if($tag -ne $null){ $tag.SuppressAutoSearch=$false }
                        }
                    }
                    try { $txtTitle.Tag.RefreshNeeded=$true } catch {}
                    Load-EditorSteamPreviews ([string]$steamFound.Id) $slots $status
                    & $tryApplySteamExeHint ([string]$steamFound.Id)
                } else {
                    $txtId.Text=''
                    foreach($sl in $slots.Values){ try { Set-EditorPreviewFile $sl $null | Out-Null } catch {} }
                    $status.Text=(T 'st_game_notfound_steam' @($name))
                }
            } catch {
                $status.Text='Steam: '+[string]$_.Exception.Message
            } finally {
                $searchSteamBtn.Enabled=$true
                $searchSgdbBtn.Enabled=$true
                $btnAdd.Enabled=$true
                Set-ConfidenceBadge $titleConfidenceBadge ($txtId.Text.Trim() -match '^\d+$') (T 'badge_title_ok') (T 'badge_title_fail_pick')
            }
            return
        }

        # SteamGridDB: Enter по-прежнему открывает список вариантов названия
        # для ручного выбора конкретного варианта.
        try {
            $txtTitle.Tag.RefreshNeeded=$true
            $hasItems=Update-EditorTitleCandidates
            if($hasItems -and $titleResults.Items.Count -gt 0){
                & $openEditorTitleDropDown
            } else {
                $status.Text = (T 'st_no_variants' @($editorState.SearchSource, $name))
            }
        } catch {}
    })

    # Enter в ID обновляет выбранный источник.
    $txtId.Add_KeyDown({
        if($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter){
            $_.SuppressKeyPress=$true
            if($txtId.Text.Trim() -match '^\d+$'){
                if($editorState.SearchSource -eq 'Steam') {
                    Load-EditorSteamPreviews $txtId.Text.Trim() $slots $status
                } else {
                    [void](Load-EditorSgdbPreviews -gameName $txtTitle.Text.Trim() -steamAppId '' -slots $slots -statusLabel $status -sgdbGameId ([int]$txtId.Text.Trim()))
                }
                # ID введён пользователем вручную и явно указывает на конкретную
                # игру — это осознанное подтверждение, а не догадка программы.
                Set-ConfidenceBadge $titleConfidenceBadge $true (T 'badge_title_ok') (T 'badge_title_fail_auto')
                if($editorState.SearchSource -eq 'Steam') { & $tryApplySteamExeHint $txtId.Text.Trim() }
            } else {
                $status.Text=if($editorState.SearchSource -eq 'Steam'){(T 'st_id_digits_steam')}else{(T 'st_id_digits_sgdb')}
            }
        }
    })

    # Подсказка exe из Steam: вынесена в переиспользуемый блок, чтобы её можно
    # было применять не только сразу при открытии карточки (когда App ID уже
    # мог быть определён автоматикой), но и после ЛЮБОГО последующего
    # подтверждения App ID — например, когда автопоиск названия не сработал
    # (см. исправление Find-SteamAppInfo для случаев вроде "Crash Bandicoot 4"
    # / официального "Crash Bandicoot™ 4: It's About Time"), а пользователь
    # нашёл и подтвердил игру вручную (из списка вариантов, повторным Enter
    # по названию, или вводом App ID напрямую). Раньше в этих случаях exe так
    # и оставался неопределённым (красный "!") до конца работы с карточкой,
    # хотя после подтверждения App ID подсказка от Steam уже могла сработать.
    #
    # Применяется только если выбор exe ещё НЕ подтверждён ($editorState.ExeConfirmed
    # -eq $false) — то есть не перетирает ни кэш/сохранённый ярлык, ни уже
    # сделанный пользователем осознанный выбор.
    $tryApplySteamExeHint = {
        param($appIdForHint)
        try {
            if ($editorState.SearchSource -ne 'Steam') { return }
            if ($editorState.ExeConfirmed) { return }
            if ([string]::IsNullOrWhiteSpace([string]$appIdForHint) -or ([string]$appIdForHint) -notmatch '^\d+$') { return }
            $hintedExe = Get-SteamHintedExecutable $gamePath ([string]$appIdForHint)
            if ($hintedExe -eq $null) { return }
            $hintIndex = -1
            for ($hi=0; $hi -lt $exeCandidates.Count; $hi++) {
                try { if ([string]::Equals([string]$exeCandidates[$hi].FullName,[string]$hintedExe.FullName,[System.StringComparison]::OrdinalIgnoreCase)) { $hintIndex=$hi; break } } catch {}
            }
            if ($hintIndex -lt 0) {
                $exeCandidates.Add($hintedExe)
                $hintIndex = $exeCandidates.Count-1
                $relHint = [string]$hintedExe.FullName
                try { if ($hintedExe.FullName.StartsWith($gamePath,[System.StringComparison]::OrdinalIgnoreCase)) { $relHint = $hintedExe.FullName.Substring($gamePath.Length).TrimStart('\') } } catch {}
                $icoHint = $null
                try { $icoHint=[System.Drawing.Icon]::ExtractAssociatedIcon($hintedExe.FullName) } catch {}
                $exeDisplay.Add([PSCustomObject]@{ Text=$relHint; Image=$icoHint })
                $cmbExe.Tag = $exeDisplay.ToArray()
                [void]$cmbExe.Items.Add($relHint)
            }
            $exeProgrammaticSelect = $true
            try {
                $cmbExe.SelectedIndex = -1
                $cmbExe.SelectedIndex = $hintIndex
                $cmbExe.Refresh()
            } finally { $exeProgrammaticSelect = $false }
            $editorState.ExeConfirmed = $true
            Set-ConfidenceBadge $exeConfidenceBadge $true (T 'badge_exe_steam') ''
        } catch {}
    }

    $dlg.Add_Shown({
        # Каждая карточка начинает с чистых временных обложек (см. Clear-TempCoverFiles).
        # В режиме редактирования Copy-ExistingShortcutCoversToTemp ниже всё равно
        # перезапишет их обложками существующего ярлыка.
        Clear-TempCoverFiles
        $status.Text=if($editorState.SearchSource -eq 'Steam'){(T 'st_resolving_steam')}else{(T 'st_resolving_sgdb')}
        # Анимацию включаем сразу при открытии карточки: определение App ID —
        # тоже часть пути к миниатюрам, и до конца этого пути слот показывает
        # спиннер, а не крест. Крест появится только в ветке "App ID не
        # определён" — то есть когда источника обложек реально нет.
        #
        # До первого DoEvents принудительно отдаём фокус безопасному невидимому
        # sink-контролу. Иначе WinForms успевает сфокусировать txtTitle и показать
        # выделение текста прямо во время начальной загрузки.
        try {
            $dlg.ActiveControl = $editorFocusSink
            $editorFocusSink.Focus() | Out-Null
            $txtTitle.SelectionLength=0
            $txtId.SelectionLength=0
            $txtLaunchOptions.SelectionLength=0
        } catch {}
        Start-EditorLoading $slots $dlg
        [System.Windows.Forms.Application]::DoEvents()
        # Начальное автозаполнение карточки не должно считаться ручным
        # редактированием. Иначе TextChanged после установки найденного имени
        # ставит таймер поиска, а тот через 350 мс раскрывает список сам по себе.
        # Особенно заметно это на играх, для которых SGDB возвращает варианты.
        $initialTag=$txtTitle.Tag
        if($null -ne $initialTag){ $initialTag.SuppressAutoSearch=$true }
        try {
            if($editorState.SearchSource -eq 'Steam') {
                $found = Find-SteamAppInfo $txtTitle.Text.Trim()
                if($found -ne $null){
                    $txtId.Text=[string]$found.Id
                    $txtTitle.Text=[string]$found.Name
                }
            } else {
                $candidates=@(Get-EditorSgdbCandidates $txtTitle.Text.Trim() '')
                if(@($candidates).Count -gt 0){
                    $txtId.Text=[string]$candidates[0].Id
                    $txtTitle.Text=[string]$candidates[0].Name
                }
            }
        } catch {} finally {
            if($null -ne $initialTag){
                $initialTag.RefreshNeeded=$true
                $initialTag.SuppressAutoSearch=$false
                try { $initialTag.SearchTimer.Stop() } catch {}
            }
        }
        $titleConfidentInitial = if($editorState.SearchSource -eq 'Steam'){ $found -ne $null } else { (@($candidates).Count -gt 0) }
        Set-ConfidenceBadge $titleConfidenceBadge $titleConfidentInitial (T 'badge_title_ok') (T 'badge_title_fail_auto')
        $loadedExistingCovers=$false
        if($editMode -and $existingShortcut -ne $null){
            try {
                $loadedExistingCovers=Copy-ExistingShortcutCoversToTemp $existingShortcut
                if($loadedExistingCovers){
                    # Значок источника у уже сохранённых обложек: читаем из
                    # cover_sources\<shortcutId>.json, куда он был записан при
                    # последнем сохранении карточки. Для игр, добавленных ещё
                    # до появления этого файла, метаданных не будет — тогда,
                    # как и раньше, считаем источником Steam (это подавляющее
                    # большинство обложек).
                    $savedSources = Get-CoverSourcesMetadata ([string]$existingShortcut.ShortcutId)
                    $sourceFor = {
                        param($key)
                        if ($null -ne $savedSources -and -not [string]::IsNullOrWhiteSpace([string]$savedSources.$key)) { return [string]$savedSources.$key }
                        return 'Steam'
                    }
                    $vSource = & $sourceFor 'p'
                    $hSource = & $sourceFor 'header'
                    $heroSource = & $sourceFor 'hero'
                    $lSource = & $sourceFor 'logo'

                    if(Set-EditorPreviewFile $slots.Vertical (Join-Path $global:tempCovers 'temp_p.jpg')){ Set-EditorSourceBadge $slots.Vertical $vSource }
                    if(Set-EditorPreviewFile $slots.Horizontal (Join-Path $global:tempCovers 'temp_header.jpg')){ Set-EditorSourceBadge $slots.Horizontal $hSource }
                    if(Set-EditorPreviewFile $slots.Hero (Join-Path $global:tempCovers 'temp_hero.jpg')){ Set-EditorSourceBadge $slots.Hero $heroSource }
                    if(Set-EditorPreviewFile $slots.Logo (Join-Path $global:tempCovers 'temp_logo.png')){ Set-EditorSourceBadge $slots.Logo $lSource }
                    $slots.Vertical.ExpectedSource=$vSource
                    $slots.Horizontal.ExpectedSource=$hSource
                    $slots.Hero.ExpectedSource=$heroSource
                    $slots.Logo.ExpectedSource=$lSource
                    # Регион сохранённых обложек — из метаданных; для игр, добавленных
                    # раньше, обложки всегда были стандартными (английскими).
                    $savedCoverLang = 'english'
                    try { if ($null -ne $savedSources -and -not [string]::IsNullOrWhiteSpace([string]$savedSources.lang)) { $savedCoverLang = [string]$savedSources.lang } } catch {}
                    Set-EditorCoverLangButton $btnCoverLang $savedCoverLang
                    $status.Text=(T 'st_covers_loaded')
                }
            } catch {}
        }

        if($loadedExistingCovers){
            # В режиме редактирования уже установленные в Steam обложки были
            # загружены выше из userdata\<account>\config\grid. НИЧЕГО не
            # очищаем и не заменяем их повторной загрузкой по App ID.
            Stop-EditorLoading $slots $dlg
        } elseif($txtId.Text -match '^\d+$'){
            if($editorState.SearchSource -eq 'Steam') {
                Load-EditorSteamPreviews $txtId.Text.Trim() $slots $status
            } else {
                [void](Load-EditorSgdbPreviews -gameName $txtTitle.Text.Trim() -steamAppId '' -slots $slots -statusLabel $status -sgdbGameId ([int]$txtId.Text.Trim()))
            }
        } else {
            Stop-EditorLoading $slots $dlg
            foreach($sl in $slots.Values){ Set-EditorPreviewFile $sl $null | Out-Null }
            $status.Text=if($editorState.SearchSource -eq 'Steam'){(T 'st_noid_hint_steam')}else{(T 'st_noid_hint_sgdb')}
        }

        # Подсказка exe из Steam — теперь через переиспользуемый блок
        # $tryApplySteamExeHint (см. его определение выше), чтобы её можно было
        # так же вызвать позже, при последующих подтверждениях App ID.
        & $tryApplySteamExeHint $txtId.Text.Trim()

        # При открытии карточки ничего не выделяем автоматически и не оставляем
        # фокус на одном из полей ввода. Важно не просто сбросить SelectionLength,
        # а реально убрать фокус с TextBox: при следующем DoEvents WinForms иначе
        # может снова показать выделение.
        try {
            $txtTitle.SelectionLength=0; $txtTitle.SelectionStart=0
            $txtId.SelectionLength=0; $txtId.SelectionStart=0
            $txtLaunchOptions.SelectionLength=0; $txtLaunchOptions.SelectionStart=0
            $dlg.ActiveControl=$editorFocusSink
            $editorFocusSink.Focus() | Out-Null
        } catch {}
        try {
            $dlg.BeginInvoke([Action]{
                try {
                    $txtTitle.SelectionLength=0; $txtTitle.SelectionStart=0
                    $txtId.SelectionLength=0; $txtId.SelectionStart=0
                    $txtLaunchOptions.SelectionLength=0; $txtLaunchOptions.SelectionStart=0
                    $dlg.ActiveControl=$editorFocusSink
                    $editorFocusSink.Focus() | Out-Null
                } catch {}
            }) | Out-Null
        } catch {}
    })

    # После создания всех остальных контролов ещё раз поднимаем поле ввода.
    # Закрытый results-combo полностью скрыт под ним, но его нативный popup
    # при DroppedDown=$true остаётся видимым поверх формы.
    $pnlTitle.BringToFront()

    $btnAdd.Add_Click({
        $name=$txtTitle.Text.Trim()
        if([string]::IsNullOrWhiteSpace($name)){ $status.Text=(T 'st_enter_title'); return }
        if($cmbExe.SelectedIndex -lt 0){ $status.Text=(T 'st_pick_exe'); return }
        $exeIndex=$cmbExe.SelectedIndex
        if($exeIndex -lt 0 -or $exeIndex -ge $exeCandidates.Count){ $status.Text=(T 'st_exe_gone'); return }
        $exePath=[string]$exeCandidates[$exeIndex].FullName
        if(-not (Test-Path $exePath)){ $status.Text=(T 'st_exe_bat_gone'); return }

        # StartDir больше не является полем интерфейса:
        # Steam получает каталог выбранного EXE/BAT автоматически.
        $startDir=[System.IO.Path]::GetDirectoryName($exePath)
        if([string]::IsNullOrWhiteSpace($startDir) -or -not (Test-Path $startDir -PathType Container)){
            $status.Text=(T 'st_no_workdir')
            return
        }
        $launchOptions=$txtLaunchOptions.Text.Trim()

        $cacheKey=$gamePath.ToUpper()
        $global:exeSelectionCache[$cacheKey]=$exePath
        $global:folderDisplayNameCache[$gamePath.ToUpper()]=$name
        $btnAdd.Enabled=$false; $searchSteamBtn.Enabled=$false; $searchSgdbBtn.Enabled=$false; $btnCoverLang.Enabled=$false; if($btnCancel -ne $null){$btnCancel.Enabled=$false}

        try {
            if($editMode){
                $steamPathProperty=(Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name 'SteamExe' -ErrorAction SilentlyContinue).SteamExe
                if([string]::IsNullOrEmpty($steamPathProperty)){$steamPathProperty='C:\Program Files (x86)\Steam\steam.exe'}
                $labelHeader.Text=(T 'hd_saving' @($name))
                [System.Windows.Forms.Application]::DoEvents()
                taskkill.exe /F /T /IM steam.exe 2>$null | Out-Null
                Start-Sleep -Seconds 2
                $steamWasKilledThisSession = $true
                $freshShortcut=Find-SteamShortcutRecord $existingShortcut.AppName $gamePath
                if($freshShortcut -eq $null){$freshShortcut=$existingShortcut}
                $shortcutId=Update-ExistingSteamShortcut $freshShortcut $name $exePath $startDir $launchOptions
                if(-not $shortcutId){
                    $reason=if($global:lastShortcutError){[string]$global:lastShortcutError}else{(T 'reason_save_shortcut')}
                    throw $reason
                }
                # Обложки сохраняем именно в userdata\<account>\config\grid
                # того же Steam-профиля, в котором лежит изменяемый shortcuts.vdf.
                $freshShortcutAfterSave=Find-SteamShortcutRecord $name $gamePath
                if($freshShortcutAfterSave -eq $null){$freshShortcutAfterSave=$freshShortcut}
                $hasCovers=Test-CoversValid
                $coversSaved=$false
                if($hasCovers){
                    $coversSaved=Save-ExistingShortcutCoversToGrid $freshShortcutAfterSave
                    if($coversSaved){
                        $newShortcutId=[string]$freshShortcutAfterSave.ShortcutId
                        Save-CoverSourcesMetadata $newShortcutId $slots ([string]$btnCoverLang.Tag.Lang) | Out-Null
                        # ID мог смениться (имя/EXE входят в CRC-32) — старый файл больше не актуален.
                        $oldShortcutId=[string]$existingShortcut.ShortcutId
                        if(-not [string]::IsNullOrWhiteSpace($oldShortcutId) -and $oldShortcutId -ne $newShortcutId){ Remove-CoverSourcesMetadata $oldShortcutId }
                    }
                }

                # Сначала гарантированно закрываем карточку. Steam запускается
                # внешним finally главного обработчика после возврата из ShowDialog.
                $status.Text=if($coversSaved){(T 'st_done_saved_covers')}elseif($hasCovers){(T 'st_saved_no_covers')}else{(T 'st_done_saved')}
                [System.Media.SystemSounds]::Asterisk.Play()
                $dlg.DialogResult=[System.Windows.Forms.DialogResult]::OK
                $dlg.Close()
                return
            }

            if([string]::IsNullOrWhiteSpace($txtId.Text) -or $txtId.Text -notmatch '^\d+$'){
                if($editorState.SearchSource -eq 'Steam'){
                    $found=Find-SteamAppInfo $name
                    if($found -ne $null){$txtId.Text=[string]$found.Id}
                } else {
                    $candidates=@(Get-EditorSgdbCandidates $name '')
                    if(@($candidates).Count -gt 0){$txtId.Text=[string]$candidates[0].Id}
                }
            }
            if($txtId.Text -match '^\d+$' -and -not (Test-Path (Join-Path $global:tempCovers 'temp_p.jpg'))){
                if($editorState.SearchSource -eq 'Steam'){
                    Load-EditorSteamPreviews $txtId.Text.Trim() $slots $status
                } else {
                    [void](Load-EditorSgdbPreviews -gameName $name -steamAppId '' -slots $slots -statusLabel $status -sgdbGameId ([int]$txtId.Text.Trim()))
                }
            }

            $steamPathProperty=(Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name 'SteamExe' -ErrorAction SilentlyContinue).SteamExe
            if([string]::IsNullOrEmpty($steamPathProperty)){$steamPathProperty='C:\Program Files (x86)\Steam\steam.exe'}
            $labelHeader.Text=(T 'hd_adding' @($name))
            [System.Windows.Forms.Application]::DoEvents()
            if(-not $batchMode){taskkill.exe /F /T /IM steam.exe 2>$null | Out-Null;Start-Sleep -Seconds 2}

            # Обе панели равноправны. При добавлении игры в Steam НЕ переносим
            # её в другую панель и НЕ создаём Junction. Steam получает реальный
            # путь к выбранному EXE/BAT там, где папка игры находится сейчас.
            $finalExe=$exePath
            $finalStart=$startDir

            $newId=Add-ShortcutToSteam $name $finalExe $finalStart $launchOptions
            if(-not $newId){$reason=if($global:lastShortcutError){[string]$global:lastShortcutError}else{(T 'reason_shortcut_fail')};throw $reason}
            $hasCovers=Test-CoversValid
            if($hasCovers){
                Copy-TempCoversDirectlyToGrid $newId | Out-Null
                Save-CoverSourcesMetadata ([string]$newId) $slots ([string]$btnCoverLang.Tag.Lang) | Out-Null
            }
            if(-not $batchMode -and (Test-Path $steamPathProperty)){Start-Process -FilePath $steamPathProperty}
            $status.Text=if($hasCovers){(T 'st_done_added_covers')}else{(T 'st_done_added_nocovers')}
            [System.Media.SystemSounds]::Asterisk.Play()
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 500
            $dlg.Close()
        } catch {
            if(-not $batchMode){try{if(Test-Path $steamPathProperty){Start-Process -FilePath $steamPathProperty}}catch{}}
            $status.Text=(T 'st_error' @([string]$_.Exception.Message))
            $btnAdd.Enabled=$true; $searchSteamBtn.Enabled=$true; $searchSgdbBtn.Enabled=$true; $btnCoverLang.Enabled=($editorState.SearchSource -eq 'Steam'); if($btnCancel -ne $null){$btnCancel.Enabled=$true}
        }
    })

    if($btnCancel -ne $null){
        $btnCancel.Add_Click({
            $script:batchCardCancelRequested = $true
            $dlg.Close()
        })
    }
    if($batchMode -and $btnSkip -ne $null){
        $btnSkip.Add_Click({
            $script:batchCardSkipRequested = $true
            $dlg.Close()
        })
    }
    # Esc закрывает карточку так же, как кнопка отмены. Порядок такой:
    #  1) открытый выпадающий список (варианты названия, список EXE) — Esc закрывает только его;
    #  2) идёт сохранение/поиск (кнопка добавления отключена) — Esc игнорируется;
    #  3) пакетный режим — нажимается «Отменить»; обычный режим — карточка просто закрывается
    #     (отдельной кнопки отмены в ней нет, результат тот же, что у крестика окна).
    $dlg.KeyPreview = $true
    $dlg.Add_KeyDown({
        if($_.KeyCode -ne [System.Windows.Forms.Keys]::Escape){ return }
        $ac = $dlg.ActiveControl
        if($ac -is [System.Windows.Forms.ComboBox] -and $ac.DroppedDown){ return }
        $_.SuppressKeyPress = $true; $_.Handled = $true
        if($titleResults.Visible){ & $closeEditorTitleDropDown; $txtTitle.Focus(); return }
        if($coverLangList.Visible){ & $hideCoverLangList; return }
        if(-not $btnAdd.Enabled){ return }
        if($btnCancel -ne $null){ $btnCancel.PerformClick() } else { $dlg.Close() }
    })
    if($batchHost -ne $null){
        # Показываем карточку не отдельным диалогом, а встроенной в панель
        # уже открытого окна пакетного добавления, и ждём её закрытия тем же
        # способом прокачки очереди сообщений, что и остальные неблокирующие
        # ожидания в этом файле — вместо вложенного ShowDialog() у отдельного
        # окна (тут это и не сработало бы: TopLevel=false).
        try { $batchHost.Panel.Controls.Clear() } catch {}
        $batchHost.Panel.Controls.Add($dlg)
        $script:__embeddedCardClosed = $false
        $dlg.Add_FormClosed({ $script:__embeddedCardClosed = $true })
        $dlg.Show()
        $dlg.BringToFront()
        [System.Windows.Forms.Application]::DoEvents()
        while(-not $script:__embeddedCardClosed){
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 15
        }
    } else {
        $dlg.ShowDialog() | Out-Null
    }
    # В режиме редактирования Steam закрывался перед записью shortcuts.vdf
    # только если пользователь реально сохранил изменения (см.
    # $steamWasKilledThisSession выше). Запускаем его здесь после полного
    # закрытия карточки — это также работает при открытии карточки двойным
    # кликом/Enter, а не только через главную кнопку — но НЕ делаем этого,
    # если Steam в этой сессии карточки не убивали: иначе он просто
    # поднимался поверх всех окон без всякой причины при обычном закрытии
    # или отмене карточки.
    if($editMode -and -not $batchMode -and $steamWasKilledThisSession){
        try {
            $steamPathProperty=(Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name 'SteamExe' -ErrorAction SilentlyContinue).SteamExe
            if([string]::IsNullOrEmpty($steamPathProperty)){$steamPathProperty='C:\Program Files (x86)\Steam\steam.exe'}
            if(Test-Path $steamPathProperty){Start-Process -FilePath $steamPathProperty}
        } catch {}
    }
    # Возвращаем фокус и передний план главному окну программы — оно является
    # владельцем карточки, но после Start-Process (запуск/перезапуск Steam)
    # Windows отдаёт передний план именно новому процессу, а не владельцу
    # закрывшегося диалога.
    if($batchHost -eq $null){
        # Это возвращение фокуса нужно только когда карточка была отдельным
        # окном поверх главной формы. Когда карточка встроена в окно
        # пакетного добавления (batchHost), поднимать главную форму нельзя —
        # она закроет собой ещё работающее окно пакета.
        try {
            if($form -ne $null){
                if($form.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized){ $form.WindowState=[System.Windows.Forms.FormWindowState]::Normal }
                $form.Show()
                $form.Activate()
                $form.BringToFront()
            }
        } catch {}
    }
    try { foreach($sl in $slots.Values){ if($sl.Stream){$sl.Stream.Dispose()} } } catch {}
    try { Get-ChildItem -Path $global:tempCovers -Filter 'editor_*' -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    Refresh-Panels
}

$btnSettings.Add_Click({
    try {
        Show-ProgramSettingsDialog | Out-Null
        if([string]::IsNullOrWhiteSpace([string]$global:steamGridDbApiKey)){
            $labelHeader.Text=(T 'sl_sg_nokey')
        } else {
            $labelHeader.Text=(T 'sl_sg_keysaved')
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            $form,
            (T 'settings_open_fail' @([string]$_.Exception.Message)),
            $global:appTitle,
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
})

$btnSelectC.Add_Click({
    $res = Show-CenteredFolderDialog (T 'pick_extra_folder') $global:dirC
    if ($res -ne $null) { $global:dirC = $res; Refresh-Panels; Save-Configuration }
})
$btnSelectD.Add_Click({
    $res = Show-CenteredFolderDialog (T 'pick_main_folder') $global:dirD
    if ($res -ne $null) { $global:dirD = $res; Refresh-Panels; Save-Configuration }
})

function Get-MovedSteamPath ($oldGameRoot, $newGameRoot, $oldPath) {
    if ([string]::IsNullOrWhiteSpace([string]$oldPath)) { return $null }
    $oldRoot = ([string]$oldGameRoot).TrimEnd('\')
    $candidate = [string]$oldPath
    if ($candidate.StartsWith($oldRoot + '\',[System.StringComparison]::OrdinalIgnoreCase)) {
        $relative = $candidate.Substring($oldRoot.Length).TrimStart('\')
        if ([string]::IsNullOrWhiteSpace($relative)) { return $newGameRoot }
        return Join-Path $newGameRoot $relative
    }
    if ($candidate.Equals($oldRoot,[System.StringComparison]::OrdinalIgnoreCase)) { return $newGameRoot }
    return $null
}

function Update-SteamShortcutAfterGameMove ($gameName, $oldGamePath, $newGamePath) {
    # Ищем ярлык ПО СТАРОМУ пути до перемещения и после переноса записываем
    # новые Exe/StartDir в shortcuts.vdf. Никаких Junction/симлинков здесь нет.
    $record = Find-SteamShortcutRecord $gameName $oldGamePath
    if ($record -eq $null) { return $false }

    $newExe = Get-MovedSteamPath $oldGamePath $newGamePath $record.Exe
    $newStart = Get-MovedSteamPath $oldGamePath $newGamePath $record.StartDir
    if ([string]::IsNullOrWhiteSpace([string]$newExe)) {
        # На всякий случай: если EXE оказался записан в другом виде, но StartDir
        # однозначно указывает на игру, сохраняем новый каталог запуска.
        $newExe = $record.Exe
    }
    if ([string]::IsNullOrWhiteSpace([string]$newStart)) {
        $newStart = $newGamePath
    }

    $result = Update-ExistingSteamShortcut $record $record.AppName $newExe $newStart $record.LaunchOptions
    return (-not [string]::IsNullOrWhiteSpace([string]$result))
}

function Move-SelectedGames($source) {
    $checkedSet = Get-CheckedSet $source
    if ($checkedSet.Count -eq 0) {
        $labelHeader.Text = (T 'st_move_first')
        return
    }

    # Обе панели равноправны. Это просто две выбранные пользователем папки:
    # игры физически перемещаются между ними. Никаких Main/Additional,
    # Steam-library-приоритетов и Junction/симлинков больше нет.
    $targetSource = if ($source -eq 'C') { 'D' } else { 'C' }
    $sourceRoot = if ($source -eq 'C') { $global:dirC } else { $global:dirD }
    $targetRoot = if ($targetSource -eq 'C') { $global:dirC } else { $global:dirD }

    $btnMoveGame.Enabled = $false
    $btnRefreshLibrary.Enabled = $false
    $btnAddToSteam.Enabled = $false

    $steamWasRunning = $false
    try { $steamWasRunning = @(Get-Process -Name steam -ErrorAction SilentlyContinue).Count -gt 0 } catch {}
    $steamPathProperty = Get-ConfiguredSteamExePath

    try {
        if ([string]::IsNullOrWhiteSpace($sourceRoot) -or -not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
            throw 'Не выбрана исходная папка.'
        }
        if ([string]::IsNullOrWhiteSpace($targetRoot) -or -not (Test-Path -LiteralPath $targetRoot -PathType Container)) {
            throw 'Не выбрана целевая папка.'
        }
        if ([System.IO.Path]::GetFullPath($sourceRoot).TrimEnd('\').Equals([System.IO.Path]::GetFullPath($targetRoot).TrimEnd('\'),[System.StringComparison]::OrdinalIgnoreCase)) {
            throw 'Исходная и целевая папки должны быть разными.'
        }

        # Steam закрываем на время изменения shortcuts.vdf, чтобы клиент не
        # перезаписал файл в момент, когда мы исправляем пути.
        if ($steamWasRunning) {
            taskkill.exe /F /T /IM steam.exe 2>$null | Out-Null
            Start-Sleep -Seconds 2
        }

        $items = @()
        foreach ($text in @($checkedSet.Keys)) {
            $name = Clean-GameName $text
            $sourcePath = Join-Path $sourceRoot $name
            $targetPath = Join-Path $targetRoot $name
            if (-not (Test-Path -LiteralPath $sourcePath -PathType Container)) {
                throw "Папка игры не найдена: $sourcePath"
            }
            if (Test-Path -LiteralPath $targetPath) {
                throw "В целевой папке уже существует игра: $name"
            }
            $size = Get-FolderSize $sourcePath
            $items += [PSCustomObject]@{ Name=$name; SourcePath=$sourcePath; TargetPath=$targetPath; Size=$size }
        }

        $totalRequiredSize = ($items | Measure-Object -Property Size -Sum).Sum
        if ($null -eq $totalRequiredSize) { $totalRequiredSize = 0 }
        $targetDriveLetter = [System.IO.Path]::GetPathRoot($targetRoot).Substring(0,2)
        $targetDrive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$targetDriveLetter'" -ErrorAction SilentlyContinue
        if ($null -eq $targetDrive -or $totalRequiredSize -gt $targetDrive.FreeSpace) {
            [System.Windows.Forms.MessageBox]::Show(
                'Недостаточно места на целевом диске!', $global:appTitle,
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            return
        }

        # Один общий прогресс-бар на всю операцию. Размеры всех выбранных
        # папок считаем заранее, поэтому переход от одной игры к другой
        # продолжает общий процент, а не возвращается к нулю.
        $aggregateTotalBytes = [int64](($items | Measure-Object -Property Size -Sum).Sum)
        if ($aggregateTotalBytes -lt 1) { $aggregateTotalBytes = 1 }
        $aggregateCompletedBytes = [int64]0
        $progressBarFolder.Value = 0
        $labelHeader.Text = (T 'move_title')
        [System.Windows.Forms.Application]::DoEvents()

        $moved = 0
        foreach ($item in $items) {
            # Start-GameCopy использует robocopy /MOVE: это реальное физическое
            # перемещение папки, а общий прогресс получает базу уже завершённых
            # папок и общий объём всей пакетной операции.
            Start-GameCopy $item.SourcePath $item.TargetPath (T 'move_title') $item.Name $aggregateCompletedBytes $aggregateTotalBytes
            if (-not (Test-Path -LiteralPath $item.TargetPath -PathType Container)) {
                throw "Не удалось переместить игру: $($item.Name)"
            }
            if (Test-Path -LiteralPath $item.SourcePath) {
                throw "Исходная папка не была удалена после перемещения: $($item.Name)"
            }

            # После физического перемещения автоматически исправляем Exe и
            # StartDir в Steam. Если ярлыка этой игры в Steam нет, это не ошибка:
            # программа просто переносит папку.
            try {
                $updated = Update-SteamShortcutAfterGameMove $item.Name $item.SourcePath $item.TargetPath
                if (-not $updated) {
                    # Не откатываем успешный перенос: игра может быть обычной
                    # папкой без нестимовского ярлыка. Для ярлыка, найденного
                    # по старому пути, Update-ExistingSteamShortcut вернёт false
                    # только при реальной ошибке записи, о которой сообщаем ниже.
                }
            } catch {
                throw "Игра «$($item.Name)» перемещена, но путь в Steam не удалось обновить: $($_.Exception.Message)"
            }
            $aggregateCompletedBytes += [int64]$item.Size
            $moved++
        }

        # Только здесь операция считается полностью завершённой: один раз
        # показываем 100%, возвращаем обычный статус и подаём один звуковой
        # сигнал независимо от количества перемещённых папок.
        $progressBarFolder.Value = 100
        $labelHeader.Text = "Перемещено: $moved из $($items.Count)"
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 400
        $progressBarFolder.Value = 0
        $labelHeader.Text = $global:mainHintText
        [System.Media.SystemSounds]::Asterisk.Play()
    } catch {
        $labelHeader.Text = "Ошибка перемещения: $($_.Exception.Message)"
    } finally {
        if ($steamWasRunning -and -not [string]::IsNullOrWhiteSpace($steamPathProperty) -and (Test-Path $steamPathProperty)) {
            try { Start-Process -FilePath $steamPathProperty } catch {}
        }
        $btnMoveGame.Enabled = $true
        $btnRefreshLibrary.Enabled = $true
        $btnAddToSteam.Enabled = $true
        $global:checkedC.Clear(); $global:checkedD.Clear()
        Refresh-Panels
    }
}

$listBoxC.Add_Enter({ $global:lastFocusedPanel = 'C' })
$listBoxD.Add_Enter({ $global:lastFocusedPanel = 'D' })
$listBoxC.Add_MouseDown({ $global:lastFocusedPanel = 'C' })
$listBoxD.Add_MouseDown({ $global:lastFocusedPanel = 'D' })

$btnMoveGame.Add_Click({
    Move-SelectedGames $global:lastFocusedPanel
})

$btnRefreshLibrary.Add_Click({
    if (-not $btnRefreshLibrary.Enabled) { return }
    $btnRefreshLibrary.Enabled = $false
    $btnMoveGame.Enabled = $false
    $btnAddToSteam.Enabled = $false
    try {
        $labelHeader.Text = (T 'st_refresh_start')
        [System.Windows.Forms.Application]::DoEvents()
        $global:hiddenGames.Clear()
        # Размеры могли устареть (папку могли перенести/удалить/докачать) —
        # на явном "Обновить" пересчитываем их заново при следующей сортировке.
        $global:folderSizeCache.Clear()
        # Явное "Обновить" — это полный пересчёт библиотеки с нуля, поэтому,
        # в отличие от закрытия карточки игры, тут отмеченные галочки тоже
        # сбрасываются намеренно.
        $global:checkedC.Clear(); $global:checkedD.Clear()
        Refresh-Panels
        $labelHeader.Text = (T 'st_refresh_done')
    } catch {
        $labelHeader.Text = (T 'st_refresh_err' @($_.Exception.Message))
    } finally {
        $btnRefreshLibrary.Enabled = $true
        # РАНЬШЕ здесь было безусловное $btnMoveGame.Enabled = $true /
        # $btnAddToSteam.Enabled = $true — из-за этого кнопка "Перенести игру"
        # включалась даже сразу после обновления, когда выше по коду все
        # галочки были явно сброшены ($global:checkedC.Clear() и т.д.) и
        # Refresh-Panels/Update-MainLibraryButtonState уже корректно её
        # выключили. Пересчитываем состояние заново по реальному количеству
        # отмеченных игр, вместо того чтобы включать кнопки вслепую.
        try { Update-MainLibraryButtonState } catch { $btnMoveGame.Enabled = $true; $btnAddToSteam.Enabled = $true }
    }
})


# Кнопка "Перенести игру" активна, как только отмечена хотя бы одна галочка
# в текущей панели. Кнопка "Добавить" на главном экране теперь скрыта по
# умолчанию — карточка одной игры открывается прямым кликом по ней, а эта
# кнопка появляется только для ПАКЕТНОГО добавления, когда отмечено 2+ игры.
# Пока идёт пакетное добавление (batchInProgress), кнопка занята под "Отменить" —
# её текст/видимость в этот момент не трогаем.
# Перерисовывает подписи главного окна после смены языка в «Настройках».
# Заголовки панелей и статусы с подстановками пересобирает Refresh-Panels,
# который вызывается сразу после сохранения настроек.
function Apply-Localization {
    $prevHint = [string]$global:mainHintText
    $global:mainHintText = (T 'hint_main')
    try { if ([string]$labelHeader.Text -eq $prevHint) { $labelHeader.Text = $global:mainHintText } } catch {}
    try {
        $btnSelectC.Text = (T 'browse')
        $btnSelectD.Text = (T 'browse')
        Set-TextBoxCue $txtSearchC (T 'search_cue')
        Set-TextBoxCue $txtSearchD (T 'search_cue')
        $lblEmptyD.Text = (T 'empty_main')
        $btnMoveGame.Text = (T 'btn_move')
        $btnRefreshLibrary.Text = (T 'btn_refresh')
        $lblBatchAuto.Text = (T 'batch_auto')
        $batchAutoTooltipText = (T 'batch_auto_tip')
        $mainToolTip.SetToolTip($pnlBatchToggle, $batchAutoTooltipText)
        $mainToolTip.SetToolTip($lblBatchAuto, $batchAutoTooltipText)
        foreach ($hs in @('C','D')) {
            $mainToolTip.SetToolTip($script:headerParts[$hs].Cb, (T 'tip_select_all'))
            $mainToolTip.SetToolTip($script:headerParts[$hs].Labels['Library'], (T 'tip_lib_header'))
        }
        $btnSettings.AccessibleName = (T 'settings_title')
        $btnSettings.AccessibleDescription = (T 'settings_desc')
        $btnAddToSteam.Text = (T 'btn_add_batch')
    } catch {}
    try { Update-SortHeaderUI 'C'; Update-SortHeaderUI 'D' } catch {}
    try { Update-MainLibraryButtonState } catch {}
    try { $listBoxC.Invalidate(); $listBoxD.Invalidate() } catch {}
}

function Update-MainLibraryButtonState {
    # Галочка "выбрать всё" над списками обновляется при любом изменении отметок.
    try { Update-SelectAllCheckbox 'C'; Update-SelectAllCheckbox 'D' } catch {}
    try {
        if ($script:batchInProgress) { return }
        $totalChecked = [int]$global:checkedC.Count + [int]$global:checkedD.Count
        $ready = [bool]$global:foldersReady
        $btnMoveGame.Enabled = ($ready -and $totalChecked -ge 1)
        if ($ready -and $totalChecked -ge 2) {
            $btnAddToSteam.Text = (T 'btn_add_batch_n' @($totalChecked))
            $btnAddToSteam.Visible = $true
            $btnAddToSteam.Enabled = $true
        } else {
            $btnAddToSteam.Visible = $false
        }
    } catch {
        try { $btnAddToSteam.Visible = $false } catch {}
    }
}

function Get-ListGameContext($listBox, $source) {
    if($listBox.SelectedItem -eq $null){return $null}
    $name=Clean-GameName $listBox.SelectedItem.ToString()
    $root=if($source -eq 'C'){$global:dirC}else{$global:dirD}
    return [PSCustomObject]@{Name=$name;Source=$source;Path=Join-Path $root $name}
}

function Show-SelectedGameCard($listBox, $source) {
    $ctx=Get-ListGameContext $listBox $source
    if($ctx -eq $null){return}
    Show-GameEditorDialog $ctx.Name $ctx.Source $ctx.Path
}

function Show-SelectedGameSize($listBox, $source) {
    $checkedSet = Get-CheckedSet $source
    if ($checkedSet.Count -gt 0) {
        # Пробел при наличии отмеченных галочками игр — считаем размер КАЖДОЙ
        # отмеченной (не только той, что сейчас выделена курсором), и сразу
        # складываем общий итог по всем отмеченным.
        $root = if ($source -eq 'C') { $global:dirC } else { $global:dirD }
        $names = @($checkedSet.Keys)
        $total = [int64]0
        $i = 0
        foreach ($name in $names) {
            $i++
            $labelHeader.Text = (T 'st_sizes_checked' @($name, $i, $names.Count))
            [System.Windows.Forms.Application]::DoEvents()
            $path = Join-Path $root $name
            $size = Get-FolderSize $path
            $global:folderSizeCache[$path.ToLowerInvariant()] = $size
            $total += $size
        }
        $listBox.Invalidate()
        $labelHeader.Text = (T 'st_checked_total' @($names.Count, ([string][Math]::Round($total / 1GB, 2)), (T 'unit_gb')))
        return
    }
    $ctx=Get-ListGameContext $listBox $source
    if($ctx -eq $null){return}
    $size=Get-FolderSize $ctx.Path
    # Кладём в тот же кэш, которым пользуется сортировка "по размеру" — так
    # посчитанный вручную (клавишей Space) размер не считается заново.
    $global:folderSizeCache[$ctx.Path.ToLowerInvariant()] = $size
    $listBox.Invalidate()
    $labelHeader.Text=(T 'st_size_one' @($ctx.Name, ([string][Math]::Round($size/1GB,2)), (T 'unit_gb')))
}

# Alt+Shift+Enter — считает размер ВСЕХ папок активной панели (не только
# отфильтрованных текущим поиском — весь набор данных панели) и показывает
# итог. Переиспользует тот же кэш и ту же функцию с прогресс-баром, которой
# уже пользуется сортировка "по размеру".
function Show-PanelFolderSizes ([string]$source) {
    $data = if ($source -eq 'C') { $script:panelDataC } else { $script:panelDataD }
    $listBox = if ($source -eq 'C') { $listBoxC } else { $listBoxD }
    if (@($data).Count -eq 0) { return }
    Ensure-FolderSizesCached $data
    $total = [int64]0
    foreach ($it in $data) {
        $s = Get-FolderSizeCached $it.Path
        if ($s -ge 0) { $total += $s }
    }
    $listBox.Invalidate()
    $labelHeader.Text = (T 'st_panel_sizes' @($data.Count, ([string][Math]::Round($total / 1GB, 2)), (T 'unit_gb')))
}

# Единый обработчик клика по строке для ОБЕИХ панелей: попадание в квадратик
# галочки — переключает отметку (для «Перенести»/«Добавить несколько»),
# любое другое место строки — только выделяет её. Карточка игры по одиночному
# клику больше НЕ открывается — см. Invoke-GamePanelDoubleClick (двойной клик)
# и Invoke-GamePanelKey (Enter).
function Invoke-GamePanelClick($listBox, $source, $e) {
    $idx = $listBox.IndexFromPoint($e.Location)
    if ($idx -lt 0 -or $idx -ge $listBox.Items.Count) { return }
    $itemBounds = $listBox.GetItemRectangle($idx)
    $cbRect = Get-RowCheckboxHitRect $itemBounds
    if ($cbRect.Contains($e.Location)) {
        $name = Clean-GameName $listBox.Items[$idx].ToString()
        $checkedSet = Get-CheckedSet $source
        if ($checkedSet.ContainsKey($name)) { $checkedSet.Remove($name) | Out-Null } else { $checkedSet[$name] = $true }
        $listBox.Invalidate($itemBounds)
        Update-MainLibraryButtonState
        return
    }
    $listBox.SelectedIndex = $idx
}
$listBoxC.Add_MouseClick({ Invoke-GamePanelClick $listBoxC 'C' $_ })
$listBoxD.Add_MouseClick({ Invoke-GamePanelClick $listBoxD 'D' $_ })

# Двойной клик по строке (вне квадратика галочки) — открывает карточку игры.
# Двойной клик по самому квадратику галочки карточку не открывает: два
# щелчка по нему — это просто снять-поставить отметку дважды подряд.
function Invoke-GamePanelDoubleClick($listBox, $source, $e) {
    $idx = $listBox.IndexFromPoint($e.Location)
    if ($idx -lt 0 -or $idx -ge $listBox.Items.Count) { return }
    $itemBounds = $listBox.GetItemRectangle($idx)
    $cbRect = Get-RowCheckboxHitRect $itemBounds
    if ($cbRect.Contains($e.Location)) { return }
    $listBox.SelectedIndex = $idx
    Show-SelectedGameCard $listBox $source
}
$listBoxC.Add_MouseDoubleClick({ Invoke-GamePanelDoubleClick $listBoxC 'C' $_ })
$listBoxD.Add_MouseDoubleClick({ Invoke-GamePanelDoubleClick $listBoxD 'D' $_ })
# Delete: убрать выбранные игры ТОЛЬКО из списка. Ни одна папка на диске не
# удаляется и не изменяется (в функции нет операций с файловой системой).
function Remove-SelectedGamesFromList($listBox, $source) {
    $names = @($listBox.SelectedItems | ForEach-Object { [string]$_ })
    if ($names.Count -eq 0) { return }
    $listBox.BeginUpdate()
    try {
        foreach ($n in $names) {
            $global:hiddenGames[(Get-HiddenGameKey $source $n)] = $true
            $listBox.Items.Remove($n)
        }
    } finally { $listBox.EndUpdate() }
    try { Update-MainLibraryButtonState } catch {}
    $labelHeader.Text = (T 'st_removed' @($names.Count))
}

# Единая клавиатурная логика для ОБЕИХ панелей (C и D).
#   Enter  — карточка игры        Space  — размер папки
#   Delete — убрать из списка     Ctrl+A — выбрать всё
# Ctrl+A в ListBox сам по себе не выделяет все элементы — делаем это вручную.
#
# БАГ-ФИКС: раньше после SetSelected() по всем элементам список сам прокручивался
# в самый низ (последним выделялся последний элемент, и ListBox "тянул" вид к нему).
# Теперь запоминаем позицию прокрутки (TopIndex) и позицию "рамки фокуса" (caret)
# до выделения и возвращаем их обратно — список остаётся на месте.
try {
    if (-not ('ListBoxCaretNative' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class ListBoxCaretNative {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    private static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);
    private const int LB_SETCARETINDEX = 0x019E;
    private const int LB_GETCARETINDEX = 0x019F;
    public static int GetCaret(IntPtr hWnd) {
        return (int)SendMessage(hWnd, LB_GETCARETINDEX, IntPtr.Zero, IntPtr.Zero);
    }
    public static void SetCaret(IntPtr hWnd, int index) {
        SendMessage(hWnd, LB_SETCARETINDEX, new IntPtr(index), new IntPtr(1));
    }
}
'@
    }
} catch {}

function Invoke-GamePanelKey($listBox, $source, $e) {
    $key = $e.KeyCode
    if ($e.Control -and -not $e.Alt -and -not $e.Shift -and $key -eq [System.Windows.Forms.Keys]::A) {
        # Раньше Ctrl+A подсвечивал (выделял) все строки для мышиного мультивыбора.
        # Теперь пакетный выбор — это галочки, поэтому Ctrl+A отмечает их все.
        $checkedSet = Get-CheckedSet $source
        for ($i = 0; $i -lt $listBox.Items.Count; $i++) {
            $name = Clean-GameName $listBox.Items[$i].ToString()
            $checkedSet[$name] = $true
        }
        $listBox.Invalidate()
        Update-MainLibraryButtonState
        $e.SuppressKeyPress = $true; $e.Handled = $true
        return
    }
    if ($e.Alt -and $e.Shift -and -not $e.Control -and $key -eq [System.Windows.Forms.Keys]::Enter) {
        # Alt+Shift+Enter — посчитать размер ВСЕХ папок активной панели разом
        # (не только отмеченных или выделенной), с тем же прогресс-баром, что
        # и у сортировки "по размеру".
        $e.SuppressKeyPress = $true; $e.Handled = $true
        Show-PanelFolderSizes $source
        return
    }
    # Остальные клавиши — только без Ctrl/Alt/Shift, чтобы не ломать стандартное
    # выделение (Shift+Space, Ctrl+Space) и не превращать Shift+Delete во что-то иное.
    if ($e.Control -or $e.Alt -or $e.Shift) { return }
    switch ($key) {
        ([System.Windows.Forms.Keys]::Enter)  { $e.SuppressKeyPress = $true; Show-SelectedGameCard $listBox $source }
        ([System.Windows.Forms.Keys]::Space)  { $e.SuppressKeyPress = $true; Show-SelectedGameSize $listBox $source }
        ([System.Windows.Forms.Keys]::Delete) { $e.SuppressKeyPress = $true; Remove-SelectedGamesFromList $listBox $source }
    }
}

$listBoxC.Add_KeyDown({ Invoke-GamePanelKey $listBoxC 'C' $_ })
$listBoxD.Add_KeyDown({ Invoke-GamePanelKey $listBoxD 'D' $_ })

$listBoxC.Add_SelectedIndexChanged({ Update-MainLibraryButtonState })
$listBoxD.Add_SelectedIndexChanged({ Update-MainLibraryButtonState })

# ===================== ПАКЕТНОЕ ДОБАВЛЕНИЕ С АВТОЗАПОЛНЕНИЕМ =====================
# Игры, для которых программа уверенно определила И название (Steam нашёл точное
# совпадение по имени папки), И исполняемый файл (единственный кандидат или уже
# закэшированный выбор — см. Add-GameToSteamQuietly), добавляются полностью
# автоматически, без показа карточки вообще. Все остальные игры показываются той
# же самой карточкой, что и в обычном пакетном режиме (три кнопки внизу:
# отменить/пропустить/добавить) — отдельным диалогом, одна за другой, точно так
# же, как в обычном пакетном добавлении (см. конец файла).
#
# Отдельного окна с собственным прогресс-баром больше нет: общий прогресс — это
# тот же $progressBarFolder главного окна, что показывает перенос папок между
# панелями (теперь это единый прогресс-бар на всю программу), а текущий статус
# выводится в $labelHeader. На время выполнения кнопка «Добавить игры»
# превращается в кнопку отмены (см. $btnAddToSteam.Add_Click) — отмена
# безопасна: она не прерывает уже начатую обработку текущей игры (тихое
# добавление или открытую карточку), а останавливает пакет перед следующей.
# Отмена кнопкой на самой карточке (см. $btnCancel в Show-GameEditorDialog)
# работает так же, как и в обычном пакетном добавлении — через тот же
# $script:batchCardCancelRequested.
function Invoke-SmartBatchAdd ($selectedGames) {
    $script:batchCardCancelRequested = $false
    $script:batchCardSkipRequested = $false
    $script:batchResults = [PSCustomObject]@{ Ok=0; AutoAdded=0; Skipped=0; Failed=0 }

    $steamPathProperty = $null
    try {
        $steamPathProperty = (Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name 'SteamExe' -ErrorAction SilentlyContinue).SteamExe
        if ([string]::IsNullOrEmpty($steamPathProperty)) { $steamPathProperty = 'C:\Program Files (x86)\Steam\steam.exe' }
        taskkill.exe /F /T /IM steam.exe 2>$null | Out-Null
        Start-Sleep -Seconds 2

        # Двухфазный пакет (без лагов на карточке):
        #  1) Быстрая классификация: авто vs нужна карточка.
        #  2) Все авто-добавления подряд (карточка ещё не открыта).
        #  3) Очередь карточек — каждая отдельным диалогом, как в обычном пакете.
        $totalGames = [Math]::Max(1, @($selectedGames).Count)
        $autoList = New-Object System.Collections.Generic.List[object]
        $cardList = New-Object System.Collections.Generic.List[object]
        $done = 0

        $progressBarFolder.Value = 0
        $labelHeader.Text = (T 'hd_classify')
        [System.Windows.Forms.Application]::DoEvents()

        for ($i = 0; $i -lt $selectedGames.Count; $i++) {
            if ($script:batchCardCancelRequested) { break }
            $game = $selectedGames[$i]
            $labelHeader.Text = (T 'hd_classify_n' @($game.Name, ($i+1), $totalGames))
            [System.Windows.Forms.Application]::DoEvents()

            # Та же проверка уверенности, что в Add-GameToSteamQuietly, но без
            # скачивания обложек и записи ярлыка — быстро и без блокировок UI надолго.
            $canAuto = $false
            try {
                $steamInfo = $null
                try { $steamInfo = Find-SteamAppInfo $game.Name } catch { $steamInfo = $null }
                if ($steamInfo -ne $null -and -not [string]::IsNullOrWhiteSpace([string]$steamInfo.Id)) {
                    $exeCandidates = @(Get-EditorExecutableCandidates $game.Path $game.Name)
                    if ($exeCandidates.Count -eq 1) {
                        $canAuto = $true
                    } elseif ($exeCandidates.Count -gt 1) {
                        $cacheKey = $game.Path.ToUpper()
                        $cached = $null
                        try { if ($global:exeSelectionCache.ContainsKey($cacheKey)) { $cached = [string]$global:exeSelectionCache[$cacheKey] } } catch {}
                        if ($cached) {
                            foreach ($ex in $exeCandidates) {
                                if ([string]::Equals([string]$ex.FullName, $cached, [System.StringComparison]::OrdinalIgnoreCase)) { $canAuto = $true; break }
                            }
                        }
                        # Нет сохранённого выбора — пробуем подсказку Steam (см.
                        # Get-SteamHintedExecutable): если основной exe для этого
                        # App ID найден в папке, карточка не нужна.
                        if (-not $canAuto) {
                            $hintedExe = $null
                            try { $hintedExe = Get-SteamHintedExecutable $game.Path ([string]$steamInfo.Id) } catch { $hintedExe = $null }
                            if ($hintedExe -ne $null) { $canAuto = $true }
                        }
                    }
                }
            } catch { $canAuto = $false }

            if ($canAuto) { $autoList.Add($game) } else { $cardList.Add($game) }
        }

        # Фаза 2: авто-добавление (карточка ещё не открыта, UI свободен).
        # Скачивание обложек внутри Add-GameToSteamQuietly по умолчанию блокирующее
        # (Invoke-WebRequest без прокачки очереди сообщений) — этого достаточно,
        # чтобы Windows пометила окно «Не отвечает» на время каждой картинки.
        # В карточке для этого включают $global:uiPumpDuringDownload — делаем то
        # же самое здесь на время всей фазы, чтобы скачивание шло через
        # Invoke-UiPumpingDownload (curl.exe-процесс + прокачка DoEvents) и окно
        # оставалось отзывчивым, включая кнопку «Отменить».
        $global:uiPumpDuringDownload = $true
        try {
            for ($i = 0; $i -lt $autoList.Count; $i++) {
                if ($script:batchCardCancelRequested) { break }
                $game = $autoList[$i]
                $labelHeader.Text = (T 'hd_auto_n' @($game.Name, ($i+1), $autoList.Count, $cardList.Count))
                $progressBarFolder.Value = [Math]::Min(100, [int](($done / $totalGames) * 100))
                [System.Windows.Forms.Application]::DoEvents()

                $quiet = Add-GameToSteamQuietly $game
                if ($quiet.Handled -and $quiet.Success) {
                    $script:batchResults.Ok++
                    $script:batchResults.AutoAdded++
                } elseif ($quiet.Handled) {
                    $script:batchResults.Failed++
                    $labelHeader.Text = (T 'hd_game_error' @($game.Name, $quiet.Reason))
                } else {
                    # На классификации казалось уверенным, на деле нет — в карточки.
                    $cardList.Add($game)
                }
                $done++
                $progressBarFolder.Value = [Math]::Min(100, [int](($done / $totalGames) * 100))
                [System.Windows.Forms.Application]::DoEvents()
            }
        } finally {
            $global:uiPumpDuringDownload = $false
        }

        # Фаза 3: очередь карточек. Каждая карточка — отдельный диалог, ровно как
        # в обычном (не авто) пакетном добавлении, а не встроенная панель.
        $cardTotal = $cardList.Count
        for ($i = 0; $i -lt $cardList.Count; $i++) {
            if ($script:batchCardCancelRequested) { break }
            $game = $cardList[$i]
            $left = $cardTotal - $i - 1
            $labelHeader.Text = (T 'hd_refine_n' @($game.Name, ($i+1), $cardTotal)) + $(if ($left -gt 0) { (T 'hd_queue_left' @($left)) } else { "" })
            $progressBarFolder.Value = [Math]::Min(100, [int](($done / $totalGames) * 100))
            [System.Windows.Forms.Application]::DoEvents()

            Show-GameEditorDialog $game.Name $game.Source $game.Path $true

            if ($script:batchCardCancelRequested) { break }
            elseif ($script:batchCardSkipRequested) { $script:batchResults.Skipped++ }
            else { $script:batchResults.Ok++ }
            $done++
            $progressBarFolder.Value = [Math]::Min(100, [int](($done / $totalGames) * 100))
            [System.Windows.Forms.Application]::DoEvents()
        }

        if ($script:batchCardCancelRequested) {
            $labelHeader.Text = (T 'hd_stopped' @($script:batchResults.Ok, $script:batchResults.AutoAdded, $script:batchResults.Skipped))
        } else {
            $progressBarFolder.Value = 100
            $labelHeader.Text = (T 'hd_finished' @($script:batchResults.Ok, $totalGames, $script:batchResults.AutoAdded, $script:batchResults.Skipped))
        }
        [System.Windows.Forms.Application]::DoEvents()
        [System.Media.SystemSounds]::Asterisk.Play()
    } catch {
        $labelHeader.Text = (T 'hd_auto_batch_err' @([string]$_.Exception.Message))
    } finally {
        try { if ($steamPathProperty -and (Test-Path $steamPathProperty)) { Start-Process -FilePath $steamPathProperty } } catch {}
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 400
        $progressBarFolder.Value = 0
    }
    return $script:batchResults
}


# В пакетном режиме карточки открываются по одной, а Steam закрывается только
# один раз перед началом операции и запускается один раз после её завершения.
$script:batchCardMode = $false

# Пока идёт автоматическое пакетное добавление (Invoke-SmartBatchAdd), кнопка
# «Добавить игры» превращается в кнопку отмены — сама кнопка остаётся
# активной (в отличие от остальных элементов управления библиотекой), чтобы
# по ней можно было кликнуть в любой момент. Отмена безопасна: она лишь
# взводит тот же $script:batchCardCancelRequested, что проверяется между
# играми внутри Invoke-SmartBatchAdd, поэтому уже начатая обработка текущей
# (последней перед остановкой) игры спокойно доходит до конца.
$script:batchInProgress = $false
$script:btnAddToSteamDefaultText = $btnAddToSteam.Text
$btnAddToSteam.Add_Click({
    if($script:batchInProgress){
        $script:batchCardCancelRequested = $true
        $labelHeader.Text = (T 'hd_cancelling')
        return
    }
    # Кнопка видна только когда отмечено 2+ игры (см. Update-MainLibraryButtonState) —
    # для ровно одной игры добавление идёт через клик по ней -> карточку, поэтому
    # отдельная ветка "выбрана одна игра" здесь больше не нужна.
    $selectedGames=@(Get-CheckedGames)
    if($selectedGames.Count -eq 0){$labelHeader.Text=(T 'hd_tick_one');return}

    $gamesToProcess=@()
    $skippedCount=0
    foreach($game in $selectedGames){
        if(Test-GameAlreadyInSteamLibrary $game.Name $game.Path){$skippedCount++}else{$gamesToProcess+=$game}
    }
    if($skippedCount -gt 0){
        $labelHeader.Text=(T 'hd_skip_existing' @($skippedCount))
        [System.Windows.Forms.Application]::DoEvents()
    }
    $selectedGames=@($gamesToProcess)
    if($selectedGames.Count -eq 0){
        $labelHeader.Text=(T 'hd_all_exist')
        return
    }

    if($script:batchAutoFillEnabled){
        # $btnAddToSteam намеренно остаётся Enabled=$true — он на время выполнения
        # исполняет роль кнопки отмены, см. перехват $script:batchInProgress в
        # начале этого обработчика. Списки тоже блокируются: пока карточка ещё не
        # открыта модально (фазы классификации и авто-добавления), главное окно
        # остаётся отзывчивым, и смена выделения в списке иначе сбросила бы текст
        # кнопки обратно через Update-MainLibraryButtonState.
        $btnMoveGame.Enabled=$false;$btnRefreshLibrary.Enabled=$false
        $listBoxC.Enabled=$false;$listBoxD.Enabled=$false
        $script:batchInProgress=$true
        $btnAddToSteam.Text=(T 'btn_cancel_batch')
        try{
            $labelHeader.Text=(T 'hd_autofill' @($selectedGames.Count))
            [System.Windows.Forms.Application]::DoEvents()
            $batchResult=Invoke-SmartBatchAdd $selectedGames
            if($batchResult -ne $null){
                if($script:batchCardCancelRequested){
                    $labelHeader.Text=(T 'hd_cancelled' @($batchResult.Ok, $selectedGames.Count, $batchResult.AutoAdded, $batchResult.Skipped))
                }else{
                    $labelHeader.Text=(T 'hd_autofill_done' @($batchResult.Ok, $selectedGames.Count, $batchResult.AutoAdded))
                }
            }
        }catch{$labelHeader.Text=(T 'hd_autofill_err' @([string]$_.Exception.Message))}
        finally{
            $script:batchInProgress=$false
            $btnAddToSteam.Text=$script:btnAddToSteamDefaultText
            $btnMoveGame.Enabled=$true;$btnRefreshLibrary.Enabled=$true;$btnAddToSteam.Enabled=$true
            $listBoxC.Enabled=$true;$listBoxD.Enabled=$true
            # Пакетное автозаполнение по отмеченным играм завершено (или
            # отменено) — отметки своё дело сделали, явно снимаем.
            $global:checkedC.Clear(); $global:checkedD.Clear()
            Refresh-Panels
        }
        return
    }

    $btnMoveGame.Enabled=$false;$btnRefreshLibrary.Enabled=$false;$btnAddToSteam.Enabled=$false
    $steamPathProperty=$null
    try{
        $steamPathProperty=(Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name 'SteamExe' -ErrorAction SilentlyContinue).SteamExe
        if([string]::IsNullOrEmpty($steamPathProperty)){$steamPathProperty='C:\Program Files (x86)\Steam\steam.exe'}
        taskkill.exe /F /T /IM steam.exe 2>$null | Out-Null
        Start-Sleep -Seconds 2
        [System.Windows.Forms.Application]::DoEvents()

        for($i=0;$i -lt $selectedGames.Count;$i++){
            $game=$selectedGames[$i]
            $labelHeader.Text=(T 'hd_card_n' @(($i+1), $selectedGames.Count, $game.Name))
            [System.Windows.Forms.Application]::DoEvents()
            Show-GameEditorDialog $game.Name $game.Source $game.Path $true
            if($script:batchCardCancelRequested){$labelHeader.Text=(T 'hd_batch_cancelled');break}
            if($script:batchCardSkipRequested){$labelHeader.Text=(T 'hd_skipped' @($game.Name));[System.Windows.Forms.Application]::DoEvents();continue}
        }
        if(-not $script:batchCardCancelRequested){$labelHeader.Text=(T 'hd_processing' @($selectedGames.Count))}
    }catch{$labelHeader.Text=(T 'hd_card_err' @([string]$_.Exception.Message))}
    finally{
        try{if($steamPathProperty -and (Test-Path $steamPathProperty)){Start-Process -FilePath $steamPathProperty}}catch{}
        $btnMoveGame.Enabled=$true;$btnRefreshLibrary.Enabled=$true;$btnAddToSteam.Enabled=$true
        # Карточки по всем отмеченным играм прошли (или добавление отменено) —
        # отметки своё дело сделали, явно снимаем.
        $global:checkedC.Clear(); $global:checkedD.Clear()
        Refresh-Panels
    }
})


$form.Add_FormClosing({ Save-Configuration })

Refresh-Panels
$form.ShowDialog() | Out-Null
