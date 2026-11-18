using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

internal static class Launcher
{
    [STAThread]
    private static int Main()
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
                start.EnvironmentVariables.Remove("HOTD4_4K_MODE");
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

                string message = errors.Trim();
                if (message.Length > 1200) message = message.Substring(message.Length - 1200);
                if (message.Length == 0) message = "The program exited with code " + child.ExitCode + ".";
                MessageBox.Show(message, title, MessageBoxButtons.OK, MessageBoxIcon.Error);
                return child.ExitCode;
            }
        }
        catch (Exception error)
        {
            MessageBox.Show(error.Message, title, MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }
}
