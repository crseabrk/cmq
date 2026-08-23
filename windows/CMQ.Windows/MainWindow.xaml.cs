using System.ComponentModel;
using System.Windows;

namespace CMQ.Windows;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        LeftPane.Partner = RightPane;
        RightPane.Partner = LeftPane;

        var settings = AppSettings.Load();
        if (settings.Width >= MinWidth && settings.Height >= MinHeight)
        {
            Width = settings.Width;
            Height = settings.Height;
        }

        Loaded += (_, _) =>
        {
            if (settings.DividerRatio is > 0.15 and < 0.85)
            {
                LeftColumn.Width = new GridLength(settings.DividerRatio, GridUnitType.Star);
                ((System.Windows.Controls.ColumnDefinition)((System.Windows.Controls.Grid)Content).ColumnDefinitions[2])
                    .Width = new GridLength(1 - settings.DividerRatio, GridUnitType.Star);
            }
        };
    }

    protected override void OnClosing(CancelEventArgs e)
    {
        var grid = (System.Windows.Controls.Grid)Content;
        var total = grid.ColumnDefinitions[0].ActualWidth + grid.ColumnDefinitions[2].ActualWidth;
        var settings = AppSettings.Load();
        settings.Width = ActualWidth;
        settings.Height = ActualHeight;
        settings.DividerRatio = total > 0 ? grid.ColumnDefinitions[0].ActualWidth / total : 0.5;
        settings.Save();
        base.OnClosing(e);
    }
}
