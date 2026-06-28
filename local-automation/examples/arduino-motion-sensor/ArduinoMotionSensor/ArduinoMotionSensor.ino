const int MotionPin = 2;
const int StatusLedPin = LED_BUILTIN;
const unsigned long SampleIntervalMs = 250;

// Most PIR motion modules drive OUT/S HIGH when motion is detected.
// If your module behaves backwards, change this to LOW.
const int MotionActiveLevel = HIGH;

unsigned long LastSampleAt = 0;

void setup()
{
  pinMode(MotionPin, INPUT);
  pinMode(StatusLedPin, OUTPUT);
  digitalWrite(StatusLedPin, LOW);
  Serial.begin(9600);
}

void loop()
{
  unsigned long now = millis();
  if (now - LastSampleAt >= SampleIntervalMs)
  {
    LastSampleAt = now;

    int pinValue = digitalRead(MotionPin);
    int motionDetected = pinValue == MotionActiveLevel ? 1 : 0;

    // The PowerShell bridge reads this one-way status line.
    Serial.print("motion=");
    Serial.println(motionDetected);

    // Local visual check only; Display Dimmer does not depend on this LED.
    digitalWrite(StatusLedPin, motionDetected ? HIGH : LOW);
  }
}
