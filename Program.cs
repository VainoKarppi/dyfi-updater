using System.Net;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

string? startDir = Path.GetDirectoryName(AppContext.BaseDirectory);

// --- Ensure settings.json exists at root ---
string settingsPath = Path.Combine(startDir ?? Directory.GetCurrentDirectory(), "settings.json");
if (!File.Exists(settingsPath))
{
    Console.WriteLine("No settings.json found, creating default settings...");
    Settings defaultSettings = new Settings();
    string json = JsonSerializer.Serialize(defaultSettings, new JsonSerializerOptions { WriteIndented = true });
    File.WriteAllText(settingsPath, json, Encoding.UTF8);
}

// --- Set current directory to root ---
if (startDir != null)
    Directory.SetCurrentDirectory(startDir);

// --- Load settings ---
Settings settings = JsonSerializer.Deserialize<Settings>(File.ReadAllText(settingsPath))!;

LogStartupInfo(settings);

DateTime nextUpdate = DateTime.Now.AddDays(settings.UpdateIntervalDays);

// --- Restore last update time ---
string lastUpdateFile = Path.Combine(Directory.GetCurrentDirectory(), "lastupdate.txt");
if (File.Exists(lastUpdateFile))
{
    DateTime lastUpdate = DateTime.Parse(File.ReadAllText(lastUpdateFile));
    Log($"Last update: {lastUpdate}");
    nextUpdate = lastUpdate.AddDays(settings.UpdateIntervalDays);
}
else
{
    await File.WriteAllTextAsync(lastUpdateFile, DateTime.Now.ToString());
}

Log($"Next scheduled update: {nextUpdate}");

// --- HTTP client ---
HttpClient client = new(new HttpClientHandler { AllowAutoRedirect = false });

// --- Wait for internet connection ---
string lastIp = await WaitForIpAsync(client);

// --- Main monitor loop ---
while (true)
{
    try
    {
        string currentIp = await GetIpAddressAsync(client);
        DateTime now = DateTime.Now;

        if (settings.UpdateNow || now > nextUpdate || lastIp != currentIp)
        {
            foreach (var domain in settings.DomainNames)
            {
                string domainToUpdate = domain;
                if (!domainToUpdate.ToLower().Contains("dy.fi"))
                    domainToUpdate += ".dy.fi";

                string requestUrl = $"http://www.dy.fi/nic/update?hostname={domainToUpdate}";
                bool updated = await UpdateDomainAsync(client, requestUrl, currentIp, settings);

                if (updated)
                    Log($"Domain '{domainToUpdate}' updated successfully to IP {currentIp}.");
                else
                    Log($"Domain '{domainToUpdate}' update failed.");
            }

            await File.WriteAllTextAsync(lastUpdateFile, DateTime.Now.ToString());
            settings.UpdateNow = false;
            lastIp = currentIp;
            nextUpdate = now.AddDays(settings.UpdateIntervalDays);
            Log($"Next scheduled update: {nextUpdate}");
        }
        else
        {
            Log($"No update needed. Current IP: {currentIp}, Next update: {nextUpdate}");
        }

        // Wait 1 hour before next check
        await Task.Delay(TimeSpan.FromHours(1));
    }
    catch (Exception ex)
    {
        Log($"ERROR: {ex.Message} - Restarting loop in 60 minutes...");
        await Task.Delay(TimeSpan.FromMinutes(60));
        client = new HttpClient(new HttpClientHandler { AllowAutoRedirect = false });
    }
}

// ---------------- METHODS ----------------

async Task<string> WaitForIpAsync(HttpClient httpClient)
{
    string ip = "";
    for (int i = -5; i < 0; i++)
    {
        await Task.Delay(1000);
        try
        {
            ip = await GetIpAddressAsync(httpClient);
            Log($"Current external IP: {ip}");
            break;
        }
        catch (Exception ex)
        {
            Log($"Failed to get IP ({Math.Abs(i)} tries left): {ex.Message}");
        }
    }

    if (string.IsNullOrEmpty(ip))
        throw new TimeoutException("No internet connection could be established!");

    return ip;
}

async Task<string> GetIpAddressAsync(HttpClient httpClient)
{
    string[] services = new[]
    {
        "http://icanhazip.com",
        "http://checkip.amazonaws.com",
        "http://api.ipify.org",
        "http://ifconfig.me"
    };

    foreach (var service in services)
    {
        try
        {
            string ip = (await httpClient.GetStringAsync(service)).Trim();
            if (!string.IsNullOrEmpty(ip))
                return ip;
        }
        catch
        {
            Log($"Failed to fetch IP from {service}, trying next...");
        }
    }

    throw new TimeoutException("Could not retrieve external IP from any service.");
}

async Task<HttpResponseMessage> WebRequestAsync(HttpClient httpClient, string url, Settings settings)
{
    var authString = Convert.ToBase64String(Encoding.UTF8.GetBytes($"{settings.Username}:{settings.Password}"));
    httpClient.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Basic", authString);

    var response = await httpClient.PostAsync(url, new StringContent(url));

    if (!response.IsSuccessStatusCode)
        throw new HttpRequestException($"Invalid status: {response.StatusCode}");

    if (response.StatusCode == HttpStatusCode.Found)
    {
        string redirect = response.Headers.Location?.ToString() ?? "unknown";
        Log($"Redirect: {redirect}");
    }

    return response;
}

async Task<bool> UpdateDomainAsync(HttpClient httpClient, string url, string ip, Settings settings)
{
    Log($"Updating domain... ({url})");
    HttpResponseMessage response = await WebRequestAsync(httpClient, url, settings);
    string responseString = (await response.Content.ReadAsStringAsync()).Trim();
    Log($"Response: {responseString}");
    return !string.IsNullOrEmpty(responseString) && (responseString.ToLower() == "nochg" || responseString.ToLower().StartsWith("good"));
}

void Log(object? data)
{
    if (data == null) return;

    string appendText = $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {data}{Environment.NewLine}";
    Console.Write(appendText);

    if (settings != null && settings.UseLogFile)
        File.AppendAllText("log.log", appendText, Encoding.UTF8);
}

void LogStartupInfo(Settings settings)
{
    Log("========== DYFI-UPDATER START ==========");
    Log($"Root directory: {Directory.GetCurrentDirectory()}");
    Log($"Username: {settings.Username}");
    Log($"Domains: {string.Join(", ", settings.DomainNames)}");
    Log($"Update interval: {settings.UpdateIntervalDays} days");
    Log($"Update immediately on start: {settings.UpdateNow}");
    Log($"Logging to file: {settings.UseLogFile}");
    Log("========================================");
}

// ---------------- SETTINGS CLASS ----------------

class Settings
{
    public string Username { get; set; } = "my.email@email.com";
    public string Password { get; set; } = "passw0rd";

    // Multiple domains
    public string[] DomainNames { get; set; } = new[] { "address.dy.fi" };

    public int UpdateIntervalDays { get; set; } = 6;
    public bool UpdateNow { get; set; } = true;
    public bool UseLogFile { get; set; } = true;

    [JsonConstructor]
    public Settings(string username, string password, string[] domainNames, int updateIntervalDays, bool updateNow, bool useLogFile) =>
        (Username, Password, DomainNames, UpdateIntervalDays, UpdateNow, UseLogFile) =
        (username, password, domainNames, updateIntervalDays, updateNow, useLogFile);

    public Settings() { }
}