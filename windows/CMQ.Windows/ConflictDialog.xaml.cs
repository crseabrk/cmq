using System.IO;
using System.Windows;

namespace CMQ.Windows;

public partial class ConflictDialog : Window
{
    public ConflictDecision Decision { get; private set; } = ConflictDecision.Cancel;
    public bool UseForAll => ApplyToAll.IsChecked == true;

    private ConflictDialog(string source, string destination, bool canMerge)
    {
        InitializeComponent();
        Heading.Text = canMerge ? "A folder with this name already exists" : "An item with this name already exists";
        Details.Text = $"Source: {Path.GetFileName(source)} — {Describe(source)}\n" +
                       $"Destination: {Path.GetFileName(destination)} — {Describe(destination)}";
        ApplyToAll.Content = $"Apply this choice to all remaining {(canMerge ? "folder" : "file")} conflicts";
        MergeButton.Visibility = canMerge ? Visibility.Visible : Visibility.Collapsed;
    }

    public static ConflictResult Ask(Window? owner, string source, string destination, bool canMerge)
    {
        var dialog = new ConflictDialog(source, destination, canMerge);
        if (owner is not null) dialog.Owner = owner;
        dialog.ShowDialog();
        return new(dialog.Decision, dialog.UseForAll);
    }

    private static string Describe(string path)
    {
        try
        {
            if (Directory.Exists(path))
                return $"Folder, modified {Directory.GetLastWriteTime(path):g}";
            var file = new FileInfo(path);
            return $"{FormatBytes(file.Length)}, modified {file.LastWriteTime:g}";
        }
        catch { return "Details unavailable"; }
    }

    private static string FormatBytes(long bytes)
    {
        string[] units = ["B", "KB", "MB", "GB", "TB"];
        double value = bytes;
        var unit = 0;
        while (value >= 1024 && unit < units.Length - 1) { value /= 1024; unit++; }
        return $"{value:0.#} {units[unit]}";
    }

    private void Finish(ConflictDecision decision) { Decision = decision; DialogResult = true; }
    private void Merge_Click(object sender, RoutedEventArgs e) => Finish(ConflictDecision.Merge);
    private void Replace_Click(object sender, RoutedEventArgs e) => Finish(ConflictDecision.Replace);
    private void KeepBoth_Click(object sender, RoutedEventArgs e) => Finish(ConflictDecision.KeepBoth);
    private void Skip_Click(object sender, RoutedEventArgs e) => Finish(ConflictDecision.Skip);
    private void Cancel_Click(object sender, RoutedEventArgs e) => Finish(ConflictDecision.Cancel);
}

public readonly record struct ConflictResult(ConflictDecision Decision, bool ApplyToAll);
