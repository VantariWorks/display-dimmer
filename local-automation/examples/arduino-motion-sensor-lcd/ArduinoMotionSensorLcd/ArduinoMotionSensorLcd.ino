#include <Adafruit_GFX.h>
#include <Adafruit_PCD8544.h>

const int MotionPin = 2;

// SparkFun Nokia 5110 / PCD8544 hookup for Arduino Uno.
const int LcdSclkPin = 13;
const int LcdDinPin = 11;
const int LcdDcPin = 5;
const int LcdCsPin = 7;
const int LcdRstPin = 6;

const unsigned long SampleIntervalMs = 250;
const unsigned long ScreenIntervalMs = 250;
const int LcdContrast = 55;

// Wire the LCD backlight separately:
// LCD LIGHT/LED -> 220-330 ohm resistor -> Arduino 3.3V.
// This keeps the demo focused on LCD text and avoids module-specific
// backlight polarity issues.

// Most PIR motion modules drive OUT/S HIGH when motion is detected.
// If your module behaves backwards, change this to LOW.
const int MotionActiveLevel = HIGH;

Adafruit_PCD8544 Display =
  Adafruit_PCD8544(LcdSclkPin, LcdDinPin, LcdDcPin, LcdCsPin, LcdRstPin);

enum BridgeStatus
{
  BridgeIdle,
  BridgeActive,
  BridgeDimmed,
  BridgeStandby,
  BridgeError
};

BridgeStatus CurrentStatus = BridgeIdle;

unsigned long LastSampleAt = 0;
unsigned long LastScreenAt = 0;
unsigned long LastMotionAt = 0;

bool MotionDetected = false;
int LastBrightness = -1;

char CommandBuffer[48];
byte CommandLength = 0;

void setup()
{
  pinMode(MotionPin, INPUT);

  Serial.begin(9600);

  Display.begin();
  Display.setContrast(LcdContrast);
  Display.clearDisplay();
  DrawStartupScreen();
}

void loop()
{
  ProcessSerialCommands();

  unsigned long now = millis();
  if (now - LastSampleAt >= SampleIntervalMs)
  {
    LastSampleAt = now;
    ReadMotion(now);
  }

  if (now - LastScreenAt >= ScreenIntervalMs)
  {
    LastScreenAt = now;
    DrawStatusScreen(now);
  }
}

void ReadMotion(unsigned long now)
{
  int pinValue = digitalRead(MotionPin);
  MotionDetected = pinValue == MotionActiveLevel;

  if (MotionDetected)
  {
    LastMotionAt = now;
  }

  Serial.print("motion=");
  Serial.println(MotionDetected ? 1 : 0);
}

void ProcessSerialCommands()
{
  while (Serial.available() > 0)
  {
    char c = (char)Serial.read();

    if (c == '\r')
      continue;

    if (c == '\n')
    {
      CommandBuffer[CommandLength] = '\0';
      HandleCommand(CommandBuffer);
      CommandLength = 0;
      continue;
    }

    if (CommandLength < sizeof(CommandBuffer) - 1)
    {
      CommandBuffer[CommandLength] = c;
      CommandLength++;
    }
    else
    {
      // Drop overlong/garbled commands instead of letting the buffer overflow.
      CommandLength = 0;
    }
  }
}

void HandleCommand(const char* command)
{
  if (strcmp(command, "status=active") == 0)
  {
    CurrentStatus = BridgeActive;
  }
  else if (strcmp(command, "status=dimmed") == 0)
  {
    CurrentStatus = BridgeDimmed;
  }
  else if (strcmp(command, "status=standby") == 0)
  {
    CurrentStatus = BridgeStandby;
  }
  else if (strcmp(command, "status=error") == 0)
  {
    CurrentStatus = BridgeError;
  }
  else if (strcmp(command, "status=idle") == 0)
  {
    CurrentStatus = BridgeIdle;
  }
  else if (strncmp(command, "brightness=", 11) == 0)
  {
    LastBrightness = atoi(command + 11);
  }
}

void DrawStartupScreen()
{
  Display.clearDisplay();
  Display.setTextSize(1);
  Display.setTextColor(BLACK);
  Display.setCursor(0, 0);
  Display.println("Display Dimmer");
  Display.println("Motion LCD");
  Display.println("");
  Display.println("Waiting...");
  Display.display();
}

void DrawStatusScreen(unsigned long now)
{
  Display.clearDisplay();
  Display.setTextSize(1);
  Display.setTextColor(BLACK);

  Display.setCursor(0, 0);
  Display.println("Display Dimmer");

  Display.setCursor(0, 10);
  Display.print("Motion: ");
  Display.println(MotionDetected ? "YES" : "NO");

  Display.setCursor(0, 20);
  Display.print("Idle: ");
  if (MotionDetected)
  {
    Display.println("0s");
  }
  else
  {
    unsigned long idleSeconds = (now - LastMotionAt) / 1000;
    Display.print(idleSeconds);
    Display.println("s");
  }

  Display.setCursor(0, 30);
  Display.print("State: ");
  Display.println(GetStatusText());

  Display.setCursor(0, 40);
  Display.print("Bright: ");
  if (LastBrightness >= 0)
  {
    Display.print(LastBrightness);
    Display.println("%");
  }
  else
  {
    Display.println("--");
  }

  Display.display();
}

const char* GetStatusText()
{
  switch (CurrentStatus)
  {
    case BridgeActive:
      return "ACTIVE";
    case BridgeDimmed:
      return "DIMMED";
    case BridgeStandby:
      return "STANDBY";
    case BridgeError:
      return "ERROR";
    case BridgeIdle:
    default:
      return "IDLE";
  }
}
