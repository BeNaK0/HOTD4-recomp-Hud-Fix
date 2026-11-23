using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

internal static class Launcher
{
    internal static string SaveErrorLog(string directory, string title, string errors, int exitCode)
    {
        try
        {
            string folder = Path.Combine(directory, "Crash Logs");
            Directory.CreateDirectory(folder);
            string path = Path.Combine(folder, "HOTD4-" + DateTime.Now.ToString("yyyyMMdd-HHmmss-fff") + "-" + Guid.NewGuid().ToString("N").Substring(0, 8) + ".log");
            File.WriteAllText(path, title + Environment.NewLine + "Time: " + DateTime.Now.ToString("O") +
                Environment.NewLine + "Exit code: " + exitCode + Environment.NewLine + Environment.NewLine + errors);
            return path;
        }
        catch
        {
            return null;
        }
    }

    internal static string FormatError(string errors, int exitCode, string log)
    {
        string message = errors.Trim();
        if (message.Length == 0) message = "The program exited with code " + exitCode + ".";
        if (message.Length > 1200)
            message = message.Substring(0, 800) + Environment.NewLine + "[...]" + Environment.NewLine +
                message.Substring(message.Length - 300);
        if (log != null)
            message = "The complete error report was saved to:" + Environment.NewLine + log +
                Environment.NewLine + Environment.NewLine + message;
        return message;
    }

    [STAThread]
    private static int Main(string[] args)
    {
        string directory = AppDomain.CurrentDomain.BaseDirectory;
        bool viewer = Path.GetFileNameWithoutExtension(Application.ExecutablePath) == "Model Viewer";
        string title = viewer ? "Model Viewer" : "The House of the Dead 4";
        try
        {
            var start = new ProcessStartInfo
            {
                FileName = Path.Combine(Environment.SystemDirectory, @"WindowsPowerShell\v1.0\powershell.exe"),
                WorkingDirectory = directory,
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                Arguments = "-NoProfile -ExecutionPolicy Bypass -STA "
            };
            if (viewer)
            {
                start.Arguments += "-File \"" + Path.Combine(directory, @"HOTD4_Recomp\hotd4-model-viewer.ps1") + "\"";
            }
            else
            {
                string script = Path.Combine(directory, "Play HOTD4.cmd");
                if (!File.Exists(script)) script = Path.Combine(directory, "Spela HOTD4 i 4K.cmd");
                if (!File.Exists(script)) throw new FileNotFoundException("Could not find the game launch script.");
                start.EnvironmentVariables["HOTD4_4K_SCRIPT"] = script;
                bool direct = Array.Exists(args, arg =>
                    String.Equals(arg, "--no-launcher", StringComparison.OrdinalIgnoreCase) ||
                    String.Equals(arg, "--skip-launcher", StringComparison.OrdinalIgnoreCase));
                start.EnvironmentVariables.Remove("HOTD4_4K_MODE");
                start.EnvironmentVariables["HOTD4_NO_LAUNCHER"] = direct ? "1" : "0";
                bool settings = Array.Exists(args, arg => String.Equals(arg, "--settings", StringComparison.OrdinalIgnoreCase));
                start.EnvironmentVariables["HOTD4_INITIAL_PAGE"] = !direct && settings ? "OptionsPage" : "MainPage";
                if (direct) start.EnvironmentVariables["HOTD4_4K_MODE"] = "0";
                start.EnvironmentVariables["HOTD4_GUI_LAUNCH"] = "1";
                start.Arguments += "-Command \"$parts = (Get-Content -Raw -Encoding UTF8 -LiteralPath $env:HOTD4_4K_SCRIPT) " +
                    "-split '(?m)^:PowerShell\\r?$', 2; & ([scriptblock]::Create($parts[1]))\"";
            }

            using (Process child = Process.Start(start))
            {
                child.BeginOutputReadLine();
                string errors = child.StandardError.ReadToEnd();
                child.WaitForExit();
                if (child.ExitCode == 0) return 0;

                string log = SaveErrorLog(directory, title, errors, child.ExitCode);
                string message = FormatError(errors, child.ExitCode, log);
                MessageBox.Show(message, title, MessageBoxButtons.OK, MessageBoxIcon.Error);
                return child.ExitCode;
            }
        }
        catch (Exception error)
        {
            string log = SaveErrorLog(directory, title, error.ToString(), 1);
            MessageBox.Show(FormatError(error.Message, 1, log), title, MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }
}
