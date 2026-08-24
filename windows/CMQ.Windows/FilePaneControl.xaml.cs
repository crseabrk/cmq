using Microsoft.VisualBasic.FileIO;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;

namespace CMQ.Windows;

public partial class FilePaneControl : UserControl
{
    public static readonly DependencyProperty PaneKeyProperty =
        DependencyProperty.Register(nameof(PaneKey), typeof(string), typeof(FilePaneControl), new PropertyMetadata("Left"));

    public string PaneKey
    {
        get => (string)GetValue(PaneKeyProperty);
        set => SetValue(PaneKeyProperty, value);
    }

    public FilePaneControl? Partner { get; set; }
    public string CurrentPath { get; private set; } = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);

    private readonly ObservableCollection<FileItem> _items = [];
    private readonly List<string> _history = [];
    private int _historyIndex = -1;
    private Point _dragStart;
    private bool _initialized;

    public FilePaneControl()
    {
        InitializeComponent();
        FileList.ItemsSource = _items;
        Loaded += (_, _) => InitializePane();
        BuildContextMenu();
    }

    private void InitializePane()
    {
        if (_initialized) return;
        _initialized = true;

        RefreshDrives();
        var settings = AppSettings.Load();
        var saved = PaneKey == "Right" ? settings.RightPath : settings.LeftPath;
        Navigate(Directory.Exists(saved) ? saved! : Environment.GetFolderPath(Environment.SpecialFolder.UserProfile));
    }

    private void RefreshDrives()
    {
        var selected = CurrentPath;
        DrivePicker.Items.Clear();
        foreach (var drive in DriveInfo.GetDrives().Where(d => d.IsReady))
            DrivePicker.Items.Add(new DriveChoice(drive.Name, string.IsNullOrWhiteSpace(drive.VolumeLabel) ? drive.Name : $"{drive.VolumeLabel} ({drive.Name.TrimEnd('\\')})"));

        DrivePicker.DisplayMemberPath = nameof(DriveChoice.Label);
        DrivePicker.SelectedValuePath = nameof(DriveChoice.Path);
        DrivePicker.SelectedItem = DrivePicker.Items.Cast<DriveChoice>()
            .FirstOrDefault(d => selected.StartsWith(d.Path, StringComparison.OrdinalIgnoreCase));
    }

    public void Navigate(string path, bool recordHistory = true)
    {
        try
        {
            var fullPath = Path.GetFullPath(Environment.ExpandEnvironmentVariables(path.Trim()));
            if (!Directory.Exists(fullPath))
                throw new DirectoryNotFoundException(fullPath);

            CurrentPath = fullPath;
            if (recordHistory)
            {
                if (_historyIndex + 1 < _history.Count)
                    _history.RemoveRange(_historyIndex + 1, _history.Count - _historyIndex - 1);
                if (_history.Count == 0 || !StringComparer.OrdinalIgnoreCase.Equals(_history[^1], fullPath))
                    _history.Add(fullPath);
                _historyIndex = _history.Count - 1;
            }

            var settings = AppSettings.Load();
            if (PaneKey == "Right") settings.RightPath = fullPath;
            else settings.LeftPath = fullPath;
            settings.Save();

            Reload();
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "Folder not available", MessageBoxButton.OK, MessageBoxImage.Warning);
        }
    }

    public void Reload()
    {
        try
        {
            var entries = new DirectoryInfo(CurrentPath).EnumerateFileSystemInfos()
                .Select(info => new FileItem(info))
                .OrderByDescending(item => item.IsDirectory)
                .ThenBy(item => item.Name, StringComparer.CurrentCultureIgnoreCase)
                .ToList();

            _items.Clear();
            foreach (var item in entries) _items.Add(item);
            PathBox.Text = CurrentPath;
            StatusText.Text = $"{_items.Count} items";
            BackButton.IsEnabled = _historyIndex > 0;
            ForwardButton.IsEnabled = _historyIndex >= 0 && _historyIndex < _history.Count - 1;
            UpButton.IsEnabled = Directory.GetParent(CurrentPath) is not null;

            DrivePicker.SelectedItem = DrivePicker.Items.Cast<DriveChoice>()
                .FirstOrDefault(d => CurrentPath.StartsWith(d.Path, StringComparison.OrdinalIgnoreCase));
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "Couldn't open folder", MessageBoxButton.OK, MessageBoxImage.Warning);
        }
    }

    private IReadOnlyList<FileItem> SelectedItems => FileList.SelectedItems.Cast<FileItem>().ToList();

    private void DrivePicker_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_initialized && DrivePicker.SelectedItem is DriveChoice drive &&
            !CurrentPath.StartsWith(drive.Path, StringComparison.OrdinalIgnoreCase))
            Navigate(drive.Path);
    }

    private void BackButton_Click(object sender, RoutedEventArgs e)
    {
        if (_historyIndex > 0) Navigate(_history[--_historyIndex], false);
    }

    private void ForwardButton_Click(object sender, RoutedEventArgs e)
    {
        if (_historyIndex + 1 < _history.Count) Navigate(_history[++_historyIndex], false);
    }

    private void UpButton_Click(object sender, RoutedEventArgs e)
    {
        var parent = Directory.GetParent(CurrentPath);
        if (parent is not null) Navigate(parent.FullName);
    }

    private void PathBox_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter) Navigate(PathBox.Text);
    }

    private void FileList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        StatusText.Text = FileList.SelectedItems.Count == 0
            ? $"{_items.Count} items"
            : $"{FileList.SelectedItems.Count} selected";
    }

    private void FileList_MouseDoubleClick(object sender, MouseButtonEventArgs e) => OpenSelection();

    private void OpenSelection()
    {
        var item = SelectedItems.FirstOrDefault();
        if (item is null) return;
        if (item.IsDirectory) Navigate(item.FullPath);
        else ShellOpen(item.FullPath);
    }

    private void FileList_PreviewMouseRightButtonDown(object sender, MouseButtonEventArgs e)
    {
        var row = FindAncestor<ListViewItem>((DependencyObject)e.OriginalSource);
        if (row is not null && !row.IsSelected)
        {
            FileList.SelectedItems.Clear();
            row.IsSelected = true;
        }
    }

    private void FileList_PreviewMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
        => _dragStart = e.GetPosition(null);

    private void FileList_PreviewMouseMove(object sender, MouseEventArgs e)
    {
        if (e.LeftButton != MouseButtonState.Pressed || SelectedItems.Count == 0) return;
        var p = e.GetPosition(null);
        if (Math.Abs(p.X - _dragStart.X) < SystemParameters.MinimumHorizontalDragDistance &&
            Math.Abs(p.Y - _dragStart.Y) < SystemParameters.MinimumVerticalDragDistance) return;

        var data = new DataObject(DataFormats.FileDrop, SelectedItems.Select(i => i.FullPath).ToArray());
        DragDrop.DoDragDrop(FileList, data, DragDropEffects.Copy | DragDropEffects.Move);
    }

    private void FileList_DragOver(object sender, DragEventArgs e)
    {
        e.Effects = e.Data.GetDataPresent(DataFormats.FileDrop)
            ? (Keyboard.Modifiers.HasFlag(ModifierKeys.Shift) ? DragDropEffects.Move : DragDropEffects.Copy)
            : DragDropEffects.None;
        e.Handled = true;
    }

    private async void FileList_Drop(object sender, DragEventArgs e)
    {
        if (e.Data.GetData(DataFormats.FileDrop) is not string[] paths) return;
        await TransferAsync(paths, CurrentPath,
            Keyboard.Modifiers.HasFlag(ModifierKeys.Shift) ? TransferMode.Move : TransferMode.Copy);
    }

    public async Task TransferAsync(IEnumerable<string> sourcePaths, string destination, TransferMode mode)
    {
        var sources = sourcePaths.Where(p => File.Exists(p) || Directory.Exists(p)).ToList();
        if (sources.Count == 0) return;

        SetTransferState(true, 0, 1, "Calculating size…");
        Partner?.SetTransferState(true, 0, 1, "Calculating size…");

        var progress = new Progress<TransferStatus>(p =>
        {
            var text = $"{(mode == TransferMode.Copy ? "Copying" : "Moving")} {p.Name} — {FormatBytes(p.Completed)} of {FormatBytes(p.Total)}";
            SetTransferState(true, p.Completed, p.Total, text);
            Partner?.SetTransferState(true, p.Completed, p.Total, text);
        });

        var errors = await Task.Run(() => TransferWorker(sources, destination, mode, progress));

        SetTransferState(false, 0, 1, "");
        Partner?.SetTransferState(false, 0, 1, "");
        Reload();
        Partner?.Reload();

        if (errors.Count > 0)
            MessageBox.Show(string.Join(Environment.NewLine, errors), "Some items could not be transferred",
                MessageBoxButton.OK, MessageBoxImage.Warning);
    }

    private List<string> TransferWorker(List<string> sources, string destination, TransferMode mode, IProgress<TransferStatus> progress)
    {
        var errors = new List<string>();
        long total = Math.Max(1, sources.Sum(ByteSize));
        long completed = 0;
        var conflicts = new ConflictSession();

        foreach (var source in sources)
        {
            if (conflicts.Cancelled) break;
            try
            {
                var target = Path.Combine(destination, Path.GetFileName(source));
                TransferRecursively(source, target, mode, conflicts, bytes =>
                {
                    completed += bytes;
                    progress.Report(new(completed, total, Path.GetFileName(source)));
                });
            }
            catch (Exception ex)
            {
                errors.Add($"{Path.GetFileName(source)}: {ex.Message}");
            }
        }

        return errors;
    }

    private static long ByteSize(string path)
    {
        try
        {
            if (File.Exists(path)) return new FileInfo(path).Length;
            return Directory.EnumerateFiles(path, "*", System.IO.SearchOption.AllDirectories)
                .Sum(file => { try { return new FileInfo(file).Length; } catch { return 0L; } });
        }
        catch { return 0; }
    }

    private bool TransferRecursively(string source, string originalTarget, TransferMode mode,
        ConflictSession conflicts, Action<long> report)
    {
        if (conflicts.Cancelled) return false;
        var target = originalTarget;
        var sourceIsDirectory = Directory.Exists(source);

        if (File.Exists(target) || Directory.Exists(target))
        {
            var canMerge = sourceIsDirectory && Directory.Exists(target);
            var decision = ResolveConflict(source, target, canMerge, conflicts);
            switch (decision)
            {
                case ConflictDecision.Merge when canMerge:
                    break;
                case ConflictDecision.Replace:
                    if (Directory.Exists(target)) Directory.Delete(target, true);
                    else File.Delete(target);
                    break;
                case ConflictDecision.KeepBoth:
                    target = UniqueDestination(Path.GetDirectoryName(target)!, Path.GetFileName(target));
                    break;
                case ConflictDecision.Skip:
                    report(ByteSize(source));
                    return false;
                case ConflictDecision.Cancel:
                    conflicts.Cancelled = true;
                    return false;
                default:
                    return false;
            }
        }

        if (sourceIsDirectory)
        {
            Directory.CreateDirectory(target);
            var completed = true;
            foreach (var child in Directory.EnumerateFileSystemEntries(source).ToList())
            {
                var childCompleted = TransferRecursively(child, Path.Combine(target, Path.GetFileName(child)),
                    mode, conflicts, report);
                completed = completed && childCompleted;
                if (conflicts.Cancelled) { completed = false; break; }
            }
            try { Directory.SetLastWriteTime(target, Directory.GetLastWriteTime(source)); } catch { }
            if (mode == TransferMode.Move && completed) Directory.Delete(source, false);
            return completed;
        }

        CopyFile(source, target, report);
        if (mode == TransferMode.Move) File.Delete(source);
        return true;
    }

    private static void CopyFile(string source, string target, Action<long> report)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(target)!);
        using var input = new FileStream(source, FileMode.Open, FileAccess.Read, FileShare.Read, 1024 * 1024, FileOptions.SequentialScan);
        using var output = new FileStream(target, FileMode.CreateNew, FileAccess.Write, FileShare.None, 1024 * 1024);
        var buffer = new byte[1024 * 1024];
        int read;
        while ((read = input.Read(buffer, 0, buffer.Length)) > 0)
        {
            output.Write(buffer, 0, read);
            report(read);
        }
        File.SetLastWriteTime(target, File.GetLastWriteTime(source));
    }

    private ConflictDecision ResolveConflict(string source, string destination, bool canMerge, ConflictSession session)
    {
        var saved = canMerge ? session.FolderDecisionForAll : session.FileDecisionForAll;
        if (saved is not null) return saved.Value;

        var result = Dispatcher.Invoke(() =>
            ConflictDialog.Ask(Window.GetWindow(this), source, destination, canMerge));
        if (result.ApplyToAll && result.Decision != ConflictDecision.Cancel)
        {
            if (canMerge) session.FolderDecisionForAll = result.Decision;
            else session.FileDecisionForAll = result.Decision;
        }
        return result.Decision;
    }

    private static string UniqueDestination(string folder, string name)
    {
        var target = Path.Combine(folder, name);
        if (!File.Exists(target) && !Directory.Exists(target)) return target;
        var extension = Path.GetExtension(name);
        var stem = Path.GetFileNameWithoutExtension(name);
        for (var n = 2; ; n++)
        {
            target = Path.Combine(folder, $"{stem} {n}{extension}");
            if (!File.Exists(target) && !Directory.Exists(target)) return target;
        }
    }

    private void SetTransferState(bool active, double value, double maximum, string text)
    {
        FileList.IsEnabled = !active;
        TransferProgress.Visibility = active ? Visibility.Visible : Visibility.Collapsed;
        TransferProgress.Maximum = Math.Max(1, maximum);
        TransferProgress.Value = Math.Min(value, maximum);
        if (active) StatusText.Text = text;
    }

    private void BuildContextMenu()
    {
        var menu = new ContextMenu();
        menu.Opened += (_, _) =>
        {
            menu.Items.Clear();
            AddMenu(menu, "Open", (_, _) => OpenSelection(), SelectedItems.Count > 0);
            AddMenu(menu, "Open with…", (_, _) => OpenWith(), SelectedItems.Count == 1 && !SelectedItems[0].IsDirectory);
            AddMenu(menu, "Preview", (_, _) => PreviewSelection(), SelectedItems.Count > 0);
            menu.Items.Add(new Separator());
            AddMenu(menu, "Copy to Other Pane", async (_, _) => await CopyToPartner(TransferMode.Copy), SelectedItems.Count > 0 && Partner is not null);
            AddMenu(menu, "Move to Other Pane", async (_, _) => await CopyToPartner(TransferMode.Move), SelectedItems.Count > 0 && Partner is not null);
            AddMenu(menu, "Duplicate", async (_, _) => await TransferAsync(SelectedItems.Select(i => i.FullPath), CurrentPath, TransferMode.Copy), SelectedItems.Count > 0);
            menu.Items.Add(new Separator());
            AddMenu(menu, "Rename…", (_, _) => RenameSelection(), SelectedItems.Count == 1);
            AddMenu(menu, "New Folder…", (_, _) => NewFolder());
            AddMenu(menu, "Move to Recycle Bin", (_, _) => TrashSelection(), SelectedItems.Count > 0);
            menu.Items.Add(new Separator());
            AddMenu(menu, "Show in File Explorer", (_, _) => RevealSelection(), SelectedItems.Count > 0);
            AddMenu(menu, "Copy Path", (_, _) => CopyPath(), SelectedItems.Count > 0);
            AddMenu(menu, "Properties", (_, _) => ShowProperties(), SelectedItems.Count == 1);
            AddMenu(menu, "Refresh", (_, _) => Reload());
        };
        FileList.ContextMenu = menu;
    }

    private static void AddMenu(ContextMenu menu, string title, RoutedEventHandler action, bool enabled = true)
    {
        var item = new MenuItem { Header = title, IsEnabled = enabled };
        item.Click += action;
        menu.Items.Add(item);
    }

    private async Task CopyToPartner(TransferMode mode)
    {
        if (Partner is not null)
            await Partner.TransferAsync(SelectedItems.Select(i => i.FullPath), Partner.CurrentPath, mode);
    }

    private void PreviewSelection()
    {
        foreach (var item in SelectedItems) ShellOpen(item.FullPath);
    }

    private void OpenWith()
    {
        var item = SelectedItems.FirstOrDefault();
        if (item is not null)
            Process.Start(new ProcessStartInfo("rundll32.exe", $"shell32.dll,OpenAs_RunDLL \"{item.FullPath}\"") { UseShellExecute = true });
    }

    private void RenameSelection()
    {
        var item = SelectedItems.FirstOrDefault();
        if (item is null) return;
        var name = Prompt.Show("Rename", "New name:", item.Name);
        if (string.IsNullOrWhiteSpace(name) || name.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0) return;
        try
        {
            var target = Path.Combine(CurrentPath, name);
            if (item.IsDirectory) Directory.Move(item.FullPath, target);
            else File.Move(item.FullPath, target);
            Reload();
        }
        catch (Exception ex) { ShowOperationError("Couldn't rename item", ex); }
    }

    private void NewFolder()
    {
        var name = Prompt.Show("New Folder", "Folder name:", "Untitled Folder");
        if (string.IsNullOrWhiteSpace(name) || name.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0) return;
        try { Directory.CreateDirectory(Path.Combine(CurrentPath, name)); Reload(); }
        catch (Exception ex) { ShowOperationError("Couldn't create folder", ex); }
    }

    private void TrashSelection()
    {
        if (MessageBox.Show("Move the selected items to the Recycle Bin?", "CMQ",
                MessageBoxButton.OKCancel, MessageBoxImage.Warning) != MessageBoxResult.OK) return;
        foreach (var item in SelectedItems)
        {
            try
            {
                if (item.IsDirectory)
                    FileSystem.DeleteDirectory(item.FullPath, UIOption.OnlyErrorDialogs, RecycleOption.SendToRecycleBin);
                else
                    FileSystem.DeleteFile(item.FullPath, UIOption.OnlyErrorDialogs, RecycleOption.SendToRecycleBin);
            }
            catch (Exception ex) { ShowOperationError($"Couldn't recycle {item.Name}", ex); }
        }
        Reload();
    }

    private void RevealSelection()
    {
        var item = SelectedItems.FirstOrDefault();
        if (item is not null)
            Process.Start(new ProcessStartInfo("explorer.exe", $"/select,\"{item.FullPath}\"") { UseShellExecute = true });
    }

    private void CopyPath() => Clipboard.SetText(string.Join(Environment.NewLine, SelectedItems.Select(i => i.FullPath)));

    private void ShowProperties()
    {
        var item = SelectedItems.FirstOrDefault();
        if (item is not null)
            Process.Start(new ProcessStartInfo(item.FullPath) { Verb = "properties", UseShellExecute = true });
    }

    private static void ShellOpen(string path) => Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });

    private static void ShowOperationError(string title, Exception ex)
        => MessageBox.Show(ex.Message, title, MessageBoxButton.OK, MessageBoxImage.Warning);

    private static T? FindAncestor<T>(DependencyObject current) where T : DependencyObject
    {
        while (current is not null)
        {
            if (current is T value) return value;
            current = VisualTreeHelper.GetParent(current);
        }
        return null;
    }

    private static string FormatBytes(long bytes)
    {
        string[] units = ["bytes", "KB", "MB", "GB", "TB"];
        var value = (double)bytes;
        var unit = 0;
        while (value >= 1024 && unit < units.Length - 1) { value /= 1024; unit++; }
        return unit == 0 ? $"{bytes} bytes" : $"{value:0.#} {units[unit]}";
    }

    private sealed record DriveChoice(string Path, string Label);
    private sealed record TransferStatus(long Completed, long Total, string Name);
}

public enum TransferMode { Copy, Move }

public enum ConflictDecision { Merge, Replace, KeepBoth, Skip, Cancel }

internal sealed class ConflictSession
{
    public ConflictDecision? FolderDecisionForAll { get; set; }
    public ConflictDecision? FileDecisionForAll { get; set; }
    public bool Cancelled { get; set; }
}

public sealed class FileItem
{
    public string FullPath { get; }
    public string Name { get; }
    public bool IsDirectory { get; }
    public long? Size { get; }
    public DateTime Modified { get; }
    public string DisplaySize => IsDirectory ? "—" : Format(Size ?? 0);
    public string DisplayModified => Modified.ToString("g", CultureInfo.CurrentCulture);

    public FileItem(FileSystemInfo info)
    {
        FullPath = info.FullName;
        Name = info.Name;
        IsDirectory = info is DirectoryInfo;
        Size = info is FileInfo file ? file.Length : null;
        Modified = info.LastWriteTime;
    }

    private static string Format(long bytes)
    {
        string[] units = ["bytes", "KB", "MB", "GB", "TB"];
        var value = (double)bytes;
        var unit = 0;
        while (value >= 1024 && unit < units.Length - 1) { value /= 1024; unit++; }
        return unit == 0 ? $"{bytes} bytes" : $"{value:0.#} {units[unit]}";
    }
}

internal static class Prompt
{
    public static string? Show(string title, string message, string initialValue)
    {
        var window = new Window
        {
            Title = title,
            Width = 380,
            Height = 155,
            ResizeMode = ResizeMode.NoResize,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            Owner = Application.Current.MainWindow,
            ShowInTaskbar = false
        };
        var grid = new Grid { Margin = new Thickness(12) };
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        var label = new TextBlock { Text = message, Margin = new Thickness(0, 0, 0, 7) };
        var field = new TextBox { Text = initialValue, MinHeight = 26 };
        Grid.SetRow(field, 1);
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0, 10, 0, 0) };
        var ok = new Button { Content = "OK", IsDefault = true, MinWidth = 80 };
        var cancel = new Button { Content = "Cancel", IsCancel = true, MinWidth = 80 };
        ok.Click += (_, _) => window.DialogResult = true;
        buttons.Children.Add(ok); buttons.Children.Add(cancel);
        Grid.SetRow(buttons, 2);
        grid.Children.Add(label); grid.Children.Add(field); grid.Children.Add(buttons);
        window.Content = grid;
        field.SelectAll();
        return window.ShowDialog() == true ? field.Text : null;
    }
}
