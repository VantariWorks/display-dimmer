using System;
using System.Diagnostics;
using System.IO;
using System.Text.Json;

namespace DisplayDimmer.CliClientExample
{
    internal static class Program
    {
        private static int Main(string[] args)
        {
            string cliPath = args.Length > 0
                ? args[0]
                : "DisplayDimmer.Cli.exe";

            int brightness = 70;
            if (args.Length > 1 && !int.TryParse(args[1], out brightness))
            {
                Console.Error.WriteLine("Brightness must be an integer from 0 to 100.");
                return 1;
            }

            brightness = Clamp(brightness, 0, 100);

            if (LooksLikePath(cliPath) && !File.Exists(cliPath))
            {
                Console.Error.WriteLine("DisplayDimmer.Cli.exe was not found: " + cliPath);
                Console.Error.WriteLine("Pass the CLI path or command as the first argument.");
                return 2;
            }

            var list = RunCli(cliPath, "--list-displays", "--json");
            if (list.ExitCode != 0)
            {
                Console.Error.WriteLine(list.StandardError);
                Console.Error.WriteLine(list.StandardOutput);
                return list.ExitCode;
            }

            string targetId = FindFirstTargetId(list.StandardOutput);
            if (string.IsNullOrWhiteSpace(targetId))
            {
                Console.Error.WriteLine("No controllable display targetId was returned by Display Dimmer.");
                return 3;
            }

            Console.WriteLine("Using targetId: " + targetId);

            var set = RunCli(
                cliPath,
                "--set-brightness",
                brightness.ToString(),
                "--target",
                targetId,
                "--source",
                "csharp-client-example",
                "--json");

            Console.WriteLine(set.StandardOutput);
            if (set.ExitCode != 0)
            {
                Console.Error.WriteLine(set.StandardError);
                return set.ExitCode;
            }

            var state = RunCli(cliPath, "--get-state", "--target", targetId, "--pretty");
            Console.WriteLine(state.StandardOutput);
            return state.ExitCode;
        }

        private static CliResult RunCli(string cliPath, params string[] arguments)
        {
            var start = new ProcessStartInfo();
            start.FileName = cliPath;
            start.UseShellExecute = false;
            start.RedirectStandardOutput = true;
            start.RedirectStandardError = true;
            start.CreateNoWindow = true;

            for (int i = 0; i < arguments.Length; i++)
                start.ArgumentList.Add(arguments[i]);

            try
            {
                using (var process = Process.Start(start))
                {
                    if (process == null)
                        return new CliResult(5, string.Empty, "Failed to start DisplayDimmer.Cli.exe.");

                    string stdout = process.StandardOutput.ReadToEnd();
                    string stderr = process.StandardError.ReadToEnd();
                    process.WaitForExit();
                    return new CliResult(process.ExitCode, stdout, stderr);
                }
            }
            catch (Exception ex)
            {
                return new CliResult(5, string.Empty, "Failed to start DisplayDimmer.Cli.exe: " + ex.Message);
            }
        }

        private static bool LooksLikePath(string value)
        {
            return !string.IsNullOrWhiteSpace(value) &&
                   (Path.IsPathRooted(value) ||
                    value.IndexOf('\\') >= 0 ||
                    value.IndexOf('/') >= 0);
        }

        private static string FindFirstTargetId(string json)
        {
            using (var doc = JsonDocument.Parse(json))
            {
                JsonElement root = doc.RootElement;
                JsonElement displays;
                if (!root.TryGetProperty("displays", out displays) || displays.ValueKind != JsonValueKind.Array)
                    return null;

                foreach (JsonElement display in displays.EnumerateArray())
                {
                    bool controlEnabled = GetBoolean(display, "controlEnabled");
                    if (!controlEnabled)
                        continue;

                    string targetId = GetString(display, "targetId");
                    if (!string.IsNullOrWhiteSpace(targetId))
                        return targetId;
                }
            }

            return null;
        }

        private static bool GetBoolean(JsonElement element, string propertyName)
        {
            JsonElement value;
            return element.TryGetProperty(propertyName, out value) &&
                   value.ValueKind == JsonValueKind.True;
        }

        private static string GetString(JsonElement element, string propertyName)
        {
            JsonElement value;
            if (!element.TryGetProperty(propertyName, out value) || value.ValueKind != JsonValueKind.String)
                return null;

            return value.GetString();
        }

        private static int Clamp(int value, int min, int max)
        {
            if (value < min) return min;
            if (value > max) return max;
            return value;
        }

        private sealed class CliResult
        {
            public CliResult(int exitCode, string standardOutput, string standardError)
            {
                ExitCode = exitCode;
                StandardOutput = standardOutput ?? string.Empty;
                StandardError = standardError ?? string.Empty;
            }

            public int ExitCode { get; private set; }
            public string StandardOutput { get; private set; }
            public string StandardError { get; private set; }
        }
    }
}
