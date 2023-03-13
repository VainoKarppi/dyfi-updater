
using System.Net;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;


string? startDir = Path.GetDirectoryName(AppDomain.CurrentDomain.BaseDirectory);

//--- Copy settings template to root if found
if (File.Exists("settings.json") && startDir != null && startDir != Directory.GetCurrentDirectory()) {
    if (File.Exists(startDir + @"\settings.json")) {
        File.Replace("settings.json",startDir + @"\settings.json","settings.json.old");
    } else {
        File.Copy("settings.json",startDir + @"\settings.json");
    }
}

//--- Update Root Folder
if (startDir != null) Directory.SetCurrentDirectory(startDir!);
Log("Starting program...");
Log($"RootDir: {Directory.GetCurrentDirectory()}");


//--- Restore Settings
Settings settings = new Settings();
settings  = JsonSerializer.Deserialize<Settings>(File.ReadAllText("settings.json"))!;
string username = settings.Username;
string password = settings.Password;
string domainName = settings.DomainName;
int updateIntervalDays = settings.UpdateIntervalDays;
bool updateNow = settings.UpdateNow;

Log($"Settings: Username: {username}, DomainName: {domainName}, UpdateInterval: {updateIntervalDays}, UpdateNow: {updateNow}");

//--- create last updated file
await File.WriteAllTextAsync("lastupdate.txt",DateTime.Now.ToString());

//--- Restore last update time
DateTime lastupdate = DateTime.Parse(File.ReadAllText("lastupdate.txt"));

Log($"Last update time: {lastupdate}");
Log($"Next update time: {lastupdate.AddDays(updateIntervalDays)}");

//--- Create new HTTP client
using HttpClient client = new HttpClient(new HttpClientHandler { AllowAutoRedirect = false });

//--- Wait and make sure connection is established before continue.
string lastIp = "";
for (int i = -5; i < 0; i++) {
    Thread.Sleep(1000);
    try {
        lastIp = await GetIpAdressAsync();
        Log($"Current IP Adress: {lastIp}");
        break;
    } catch (Exception ex) {
        Log($"{ex.Message} Trying again... ({Math.Abs(i)} tries left)");
    }
}
if (lastIp == "") throw new TimeoutException("No internet connection could be established!");

//--- Create url request with domain
if (!domainName.ToLower().Contains("dy.fi")) domainName += ".dy.fi";
string requestUrl = "http://www.dy.fi/nic/update?hostname=" + domainName;

//--- Start main monitor Thread
while (true) {
    string newIp = await GetIpAdressAsync();
    DateTime currentTime = DateTime.Now;
    if (updateNow || (currentTime > lastupdate.AddDays(updateIntervalDays) || lastIp != newIp)) {
        await UpdateDomainAsync(newIp);
        updateNow = false;
        lastIp = newIp;
        lastupdate = currentTime;
        Log($"Next update time: {lastupdate.AddDays(updateIntervalDays)}");
        Log($"Current IP Adress: {newIp}");
    } else {
        TimeSpan interval = lastupdate.AddDays(updateIntervalDays) - currentTime;
        Log($"Next update in: {interval.Days} days, {interval.Hours} hours");
    }
    // 30 minutes
    Thread.Sleep(1800000);
}




//!! --------|
//!! METHODS |
//!! --------|

async Task<HttpResponseMessage> WebRequestAsync(string url) {
    var authString = Convert.ToBase64String(Encoding.UTF8.GetBytes(username+":"+password));

    client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Basic", authString);
    var response = await client.PostAsync(url, new StringContent(url));

    if (response.StatusCode == HttpStatusCode.Found) {
        var urlStatus = response.Headers.GetValues("Location").First();
        Log(urlStatus);
    }
    Log($"RESPONSE: {response.Content.ReadAsStringAsync().Result.TrimEnd()}");
    return response;
}

async Task UpdateDomainAsync(string ip) {
    Log($"Updating domain... ({domainName})");
    await WebRequestAsync(requestUrl);
    await File.WriteAllTextAsync("lastupdate.txt",DateTime.Now.ToString());
}

async Task<string> GetIpAdressAsync() {
    var response = await client.GetStringAsync("http://icanhazip.com");
    return response.TrimEnd();
}

void Log(object? data) {
    if (data == null) return;
     
    string appendText = $"[{DateTime.Now.ToShortDateString()} - {DateTime.Now.ToLongTimeString()}] {data}{Environment.NewLine}";
    Console.Write(appendText);
    
    if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows)) {
        File.AppendAllText("log.log", appendText, Encoding.UTF8);
    }
}



//!! ---------|
//!! SETTINGS |
//!! ---------|

class Settings {
    public string Username { get; set; } = "my.email@email.com";
    public string Password { get; set; } = "passw0rd";
    public string DomainName { get; set; } = "address.dy.fi";
    public int UpdateIntervalDays { get; set; } = 6;
    public bool UpdateNow { get; set; } = false;

    [JsonConstructor]
    public Settings(string username, string password, string domainName, int updateIntervalDays, bool updateNow) =>
        (Username, Password, DomainName, UpdateIntervalDays, UpdateNow) = (username, password, domainName, updateIntervalDays, updateNow);


    public Settings() {
        if (!File.Exists("settings.json")) {
            string json = JsonSerializer.Serialize(this,new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText("settings.json", json);
            return;
        }
    }
}