# texttospeech

**texttospeech** implements a
[Google Cloud Text to Speech API](https://cloud.google.com/text-to-speech/)
client.

**[API Documentation](https://nimble.directory/docs/texttospeech)** ·
**[GitHub Repo](https://github.com/dom96/texttospeech)**

## Installation

Add this to your application's .nimble file:

```nim
requires "texttospeech"
```

or to install globally run:

```
nimble install texttospeech
```

## Usage

Follow the "Before you begin" steps in this document:
https://cloud.google.com/text-to-speech/docs/quickstart-protocol. Ensure that
the ``gcloud`` utility is in your PATH.

You may then compile and run the following:

```nim
import os, options

import texttospeech

# Initialise the client:
let client = newTextToSpeechClient()

# Synthesize a some text:
let filename = client.synthesizeToFolder("Hello World!", os.getCurrentDir())
echo("Saved in ", filename) # Open the file in your favourite music player.

# Modifying the options:
echo client.synthesizeToFolder(
  "Nim is the best programming language!",
  os.getCurrentDir(),
  voice=initVoiceSelectionParams(name=some("en-GB-Wavenet-A")),
  audioConfig=initAudioConfig(audioEncoding=OGG_OPUS, pitch = -5)
)
```

## Contributing

1. Fork it ( https://github.com/dom96/texttospeech/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

MIT
