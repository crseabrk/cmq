using System.Text.Json;
using System.IO;

namespace CMQ.Windows;

public sealed class AppSettings
{
    public string? LeftPath { get; set; }
    public string? RightPath { get; set; }
    public double Width { get; set; } = 1100;
    public double Height { get; set; } = 680;
    public double DividerRatio { get; set; } = 0.5;

    private static string SettingsPath
    {
        get
        {
            var folder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "CMQ");
            Directory.CreateDirectory(folder);
            return Path.Combine(folder, "settings.json");
        }
    }

    public static AppSettings Load()
    {
        try
        {
            return File.Exists(SettingsPath)
                ? JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(SettingsPath)) ?? new()
                : new();
        }
        catch
        {
            return new();
        }
    }

    public void Save()
    {
        try
        {
            File.WriteAllText(SettingsPath, JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch
        {
            // Settings failure must never prevent CMQ from closing.
        }
    }
}
