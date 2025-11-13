using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.OpenApi.Models;
using System.Collections.Generic;
using System.Linq;
using Microsoft.AspNetCore.Mvc;
using System.Text.Json;
using System.Text.Json.Serialization;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "Nomad .NET CRUD API", Version = "v1" });
});
builder.Services.AddHealthChecks();

// Configure JSON serialization
builder.Services.ConfigureHttpJsonOptions(options => {
    options.SerializerOptions.TypeInfoResolverChain.Insert(0, AppJsonSerializerContext.Default);
});

// Add in-memory data store as a singleton
builder.Services.AddSingleton<ItemRepository>();

var app = builder.Build();

// Configure the HTTP request pipeline
app.UseSwagger();
app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "Nomad .NET CRUD API v1"));

// Define API endpoints
app.MapGet("/", () => "Nomad .NET CRUD API is running!");

app.MapGet("/api/items", (ItemRepository repo) => 
    Results.Ok(repo.GetAll()));

app.MapGet("/api/items/{id}", (int id, ItemRepository repo) =>
{
    var item = repo.GetById(id);
    return item is null ? Results.NotFound() : Results.Ok(item);
});

app.MapPost("/api/items", (Item item, ItemRepository repo) =>
{
    repo.Add(item);
    return Results.Created($"/api/items/{item.Id}", item);
});

app.MapPut("/api/items/{id}", (int id, Item item, ItemRepository repo) =>
{
    if (id != item.Id)
        return Results.BadRequest();
        
    var existingItem = repo.GetById(id);
    if (existingItem is null)
        return Results.NotFound();
        
    repo.Update(item);
    return Results.NoContent();
});

app.MapDelete("/api/items/{id}", (int id, ItemRepository repo) =>
{
    var existingItem = repo.GetById(id);
    if (existingItem is null)
        return Results.NotFound();
        
    repo.Delete(id);
    return Results.NoContent();
});

// Add a health check endpoint
app.MapHealthChecks("/health");

// Add system info endpoint
app.MapGet("/info", () => Results.Ok(new
{
    hostname = System.Environment.MachineName,
    os = System.Runtime.InteropServices.RuntimeInformation.OSDescription,
    framework = System.Runtime.InteropServices.RuntimeInformation.FrameworkDescription,
    environment = app.Environment.EnvironmentName,
    processId = System.Diagnostics.Process.GetCurrentProcess().Id
}));

// Run the app
var port = int.Parse(System.Environment.GetEnvironmentVariable("PORT") ?? "8080");
app.Run($"http://0.0.0.0:{port}");

// Data model
public class Item
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public bool IsComplete { get; set; }
}

// JSON serialization context
[JsonSerializable(typeof(Item))]
[JsonSerializable(typeof(IEnumerable<Item>))]
[JsonSerializable(typeof(object))]
public partial class AppJsonSerializerContext : JsonSerializerContext
{   
}

// In-memory repository
public class ItemRepository
{
    private readonly List<Item> _items = new();
    private int _nextId = 1;

    public IEnumerable<Item> GetAll() => _items;

    public Item? GetById(int id) => _items.FirstOrDefault(i => i.Id == id);

    public void Add(Item item)
    {
        item.Id = _nextId++;
        _items.Add(item);
    }

    public void Update(Item item)
    {
        var index = _items.FindIndex(i => i.Id == item.Id);
        if (index != -1)
            _items[index] = item;
    }

    public void Delete(int id)
    {
        var index = _items.FindIndex(i => i.Id == id);
        if (index != -1)
            _items.RemoveAt(index);
    }
}
