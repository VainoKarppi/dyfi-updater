
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


//--- Restore Settings
Settings settings;
if (!File.Exists("settings.json")) {
    settings = new Settings();
    string json = JsonSerializer.Serialize(settings,new JsonSerializerOptions { WriteIndented = true });
    File.WriteAllText("settings.json", json);
} else {
    settings = JsonSerializer.Deserialize<Settings>(File.ReadAllText("settings.json"))!;
}


Log("Starting program...");
Log($"RootDir: {Directory.GetCurrentDirectory()}");

Log($"Settings: Username: {settings.Username}, settings.DomainName: {settings.DomainName}, UpdateInterval: {settings.UpdateIntervalDays}, UpdateNow: {settings.UpdateNow}");


DateTime nextUpdate = DateTime.Now.AddDays(settings.UpdateIntervalDays);

//--- Get next time (if found)
if (File.Exists("lastupdate.txt")) {
    //--- Restore last update time
    DateTime lastupdate = DateTime.Parse(File.ReadAllText("lastupdate.txt"));
    Log($"Last update time: {lastupdate}");
    nextUpdate = lastupdate.AddDays(settings.UpdateIntervalDays);
} else {
    //--- Create last updated file
    await File.WriteAllTextAsync("lastupdate.txt",DateTime.Now.ToString());
}


Log($"Next update time: {nextUpdate}");

//--- Create new HTTP client
HttpClient client = new HttpClient(new HttpClientHandler { AllowAutoRedirect = false});

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
if (!settings.DomainName.ToLower().Contains("dy.fi")) settings.DomainName += ".dy.fi";
string requestUrl = "http://www.dy.fi/nic/update?hostname=" + settings.DomainName;

//--- Start main monitor Thread
while (true) {
    try {
        string newIp = await GetIpAdressAsync();
        DateTime currentTime = DateTime.Now;
        if (settings.UpdateNow || (currentTime > nextUpdate || lastIp != newIp)) {
            bool requestSuccess = await UpdateDomainAsync(newIp);
            if (!requestSuccess) throw new HttpRequestException("Domain update failed!");
            await File.WriteAllTextAsync("lastupdate.txt",DateTime.Now.ToString());
            settings.UpdateNow = false;
            lastIp = newIp;
            nextUpdate = currentTime.AddDays(settings.UpdateIntervalDays);
            Log($"Next update time: {nextUpdate}");
            Log($"Current IP Adress: {newIp}");
        }
        
        TimeSpan interval = nextUpdate - currentTime;
        Log($"Next update in: {interval.Days} days, {interval.Hours} hours, {interval.Minutes} minutes...");
        // 60 minutes
        Thread.Sleep(60*(1000*60));
    } catch (Exception ex) {
        Console.WriteLine(ex.Message);
        
        Console.WriteLine("\nRestarting loop in 60 minutes...\n");
        Thread.Sleep(60*(1000*60));
        // Create new HTTP client just in case...
        client = new HttpClient(new HttpClientHandler { AllowAutoRedirect = false});
    }
}




//!! --------|
//!! METHODS |
//!! --------|

async Task<HttpResponseMessage> WebRequestAsync(string url) {
    var authString = Convert.ToBase64String(Encoding.UTF8.GetBytes(settings.Username+":"+settings.Password));

    client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Basic", authString);
    var response = await client.PostAsync(url, new StringContent(url));
    
    if (!response.IsSuccessStatusCode) throw new HttpRequestException($"Invalid status: {response.StatusCode}");
    if (response.StatusCode == HttpStatusCode.Found) {
        var urlStatus = response.Headers.GetValues("Location").First();
        Log(urlStatus);
    }
    return response;
}

async Task<bool> UpdateDomainAsync(string ip) {
    Log($"Updating domain... ({settings.DomainName})");
    HttpResponseMessage response = await WebRequestAsync(requestUrl);
    string? responseString = response.Content.ReadAsStringAsync().Result.TrimEnd()!;
    Log($"RESPONSE: {responseString}");
    if (string.IsNullOrEmpty(responseString)) throw new HttpRequestException("No response text");
    return responseString.ToLower() == "nochg" || responseString.ToLower().StartsWith("good");
}

async Task<string> GetIpAdressAsync() {
    var response = await client.GetStringAsync("http://icanhazip.com");
    return response.TrimEnd();
}

void Log(object? data) {
    if (data == null) return;
     
    string appendText = $"[{DateTime.Now.ToShortDateString()} - {DateTime.Now.ToLongTimeString()}] {data}{Environment.NewLine}";
    Console.Write(appendText);
    
    if (settings != null && settings.UseLogFile) {
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
    public bool UpdateNow { get; set; } = true;
    public bool UseLogFile { get; set; } = true;

    [JsonConstructor]
    public Settings(string username, string password, string domainName, int updateIntervalDays, bool updateNow, bool useLogFile) =>
        (Username, Password, DomainName, UpdateIntervalDays, UpdateNow, UseLogFile) = (username, password, domainName, updateIntervalDays, updateNow, useLogFile);

    public Settings() {}
}