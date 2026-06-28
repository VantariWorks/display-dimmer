const int SensorPin = A0;
const int StatusLedPin = LED_BUILTIN;
const unsigned long SampleIntervalMs = 250;

// PowerShell sends these status values back over serial. The Arduino only uses
// them for the built-in LED; Display Dimmer itself does not talk to the board.
enum BridgeStatus
{
  BridgeIdle,
  BridgeActive,
  BridgeStandby,
  BridgeError
};

BridgeStatus CurrentStatus = BridgeIdle;
unsigned long LastSampleAt = 0;
unsigned long LastBlinkAt = 0;
bool LedState = false;

char CommandBuffer[40];
byte CommandLength = 0;

void setup()
{
  pinMode(StatusLedPin, OUTPUT);
  digitalWrite(StatusLedPin, LOW);
  Serial.begin(9600);
}

void loop()
{
  // Keep serial command handling non-blocking so status changes can update
  // immediately while sensor readings continue on their own interval.
  ProcessSerialCommands();
  UpdateStatusLed();

  unsigned long now = millis();
  if (now - LastSampleAt >= SampleIntervalMs)
  {
    LastSampleAt = now;

    int raw = analogRead(SensorPin);
    Serial.print("raw=");
    Serial.println(raw);
  }
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
  // Commands are tiny text lines from the PowerShell bridge:
  // status=active, status=standby, status=error, status=idle.
  if (strcmp(command, "status=active") == 0)
  {
    SetStatus(BridgeActive);
  }
  else if (strcmp(command, "status=standby") == 0)
  {
    SetStatus(BridgeStandby);
  }
  else if (strcmp(command, "status=error") == 0)
  {
    SetStatus(BridgeError);
  }
  else if (strcmp(command, "status=idle") == 0)
  {
    SetStatus(BridgeIdle);
  }
}

void SetStatus(BridgeStatus status)
{
  CurrentStatus = status;
  LastBlinkAt = millis();

  if (status == BridgeActive)
  {
    LedState = true;
    digitalWrite(StatusLedPin, HIGH);
  }
  else if (status == BridgeIdle)
  {
    LedState = false;
    digitalWrite(StatusLedPin, LOW);
  }
  else
  {
    LedState = true;
    digitalWrite(StatusLedPin, HIGH);
  }
}

void UpdateStatusLed()
{
  if (CurrentStatus == BridgeActive)
  {
    digitalWrite(StatusLedPin, HIGH);
    return;
  }

  if (CurrentStatus == BridgeIdle)
  {
    digitalWrite(StatusLedPin, LOW);
    return;
  }

  // Standby blinks slowly; error blinks quickly.
  unsigned long interval = CurrentStatus == BridgeError ? 150 : 700;
  unsigned long now = millis();

  if (now - LastBlinkAt >= interval)
  {
    LastBlinkAt = now;
    LedState = !LedState;
    digitalWrite(StatusLedPin, LedState ? HIGH : LOW);
  }
}
