# texttospeech
# Copyright Dominik Picheta
# A client for the Google Cloud Text to Speech API.
import osproc, httpclient, xmltree, options, asyncdispatch, json, strutils
import base64, os, hashes

export httpclient.`==`

type
  GCloudError* = object of Exception

  TextToSpeechClientBase*[Client] = ref object
    client: Client

  AsyncTextToSpeechClient* = TextToSpeechClientBase[AsyncHttpClient]
  TextToSpeechClient* = TextToSpeechClientBase[HttpClient]

  SynthesisInput* = string | XmlNode

  SsmlVoiceGender* = enum
    SSML_VOICE_GENDER_UNSPECIFIED,
    MALE,
    FEMALE,
    NEUTRAL
  VoiceSelectionParams* = object
    languageCode*: string
    name*: Option[string]
    ssmlGender*: SsmlVoiceGender

  AudioEncoding* = enum
    LINEAR16,
    MP3,
    OGG_OPUS

  AudioConfig* = object
    audioEncoding*: AudioEncoding
    speakingRate*: range[0.25 .. 4.0]
    pitch*: range[-20.0 .. 20.0]
    volumeGainDb*: range[-96.0 .. 16.0]
    sampleHertzRate*: Option[float]
    effectsProfileId*: seq[string]

const
  baseUrl = "https://texttospeech.googleapis.com/v1beta1/"

proc getAuthToken(): string =
  let (output, exitCode) =
    execCmdEx("gcloud auth application-default print-access-token")
  if exitCode != QuitSuccess:
    raise newException(GCloudError, output)

  return output.strip()

proc newTextToSpeechClient*(): TextToSpeechClient =
  TextToSpeechClient(
    client: newHttpClient()
  )

proc newAsyncTextToSpeechClient*(): AsyncTextToSpeechClient =
  AsyncTextToSpeechClient(
    client: newAsyncHttpClient()
  )

proc toRequestData(
  input: SynthesisInput, voice: VoiceSelectionParams, audioConfig: AudioConfig
): JsonNode =
  result = newJObject()
  # SynthesisInput
  when input is string:
    result["input"] = %{
      "text": %input
    }

  elif input is XmlNode:
    result["input"] = %{
      "ssml": %($input)
    }

  # VoiceSelectionParams
  result["voice"] = %*{
    "languageCode": voice.languageCode,
    "ssmlGender": $voice.ssmlGender
  }
  if voice.name.isSome:
    result["voice"]["name"] = %voice.name.get()

  # AudioConfig
  result["audioConfig"] = %*{
    "audioEncoding": $audioConfig.audioEncoding,
    "speakingRate": audioConfig.speakingRate,
    "pitch": audioConfig.pitch,
    "volumeGainDb": audioConfig.volumeGainDb
  }
  if audioConfig.sampleHertzRate.isSome():
    result["audioConfig"]["sampleHertzRate"] = %audioConfig.sampleHertzRate.get()
    result["audioConfig"]["effectsProfileId"] = %audioConfig.effectsProfileId


proc initVoiceSelectionParams*(
  languageCode="en-GB", ssmlGender=MALE, name=none[string]()
): VoiceSelectionParams =
  VoiceSelectionParams(
    languageCode: languageCode,
    ssmlGender: ssmlGender,
    name: name
  )

proc initAudioConfig*(
  audioEncoding: AudioEncoding=MP3,
  speakingRate=1.0,
  pitch=0.0,
  volumeGainDb=0.0,
  sampleHertzRate=none[float](),
  effectsProfileId: seq[string] = @[]
): AudioConfig =
  AudioConfig(
    audioEncoding: audioEncoding,
    speakingRate: speakingRate,
    pitch: pitch,
    volumeGainDb: volumeGainDb,
    sampleHertzRate: sampleHertzRate,
    effectsProfileId: effectsProfileId
  )

proc synthesize*(
  client: TextToSpeechClient | AsyncTextToSpeechClient,
  input: SynthesisInput, voice: VoiceSelectionParams, audioConfig: AudioConfig
): Future[string] {.multisync.} =
  ## Synthesizes the specified input in accordance with the voice and audio
  ## configuration.
  ##
  ## Returns the audio content as a string of bytes.
  let data = toRequestData(input, voice, audioConfig)
  client.client.headers = newHttpHeaders(
    {
      "Content-Type": "application/json; charset=utf-8",
      "Authorization": "Bearer " & getAuthToken()
    }
  )
  let resp = await client.client.post(baseUrl & "text:synthesize", body = $data)
  if resp.code != Http200:
    raise newException(GCloudError, await resp.body)

  let respData = await resp.body
  let respJson = parseJson(respData)

  return base64.decode(respJson["audioContent"].getStr())

proc synthesizeToFolder*(
  client: TextToSpeechClient | AsyncTextToSpeechClient,
  input: SynthesisInput, folder: string,
  voice: VoiceSelectionParams=initVoiceSelectionParams(),
  audioConfig: AudioConfig=initAudioConfig()
): Future[string] {.multisync.} =
  ## Synthesizes the specified input in accordance with the voice and audio
  ## configuration.
  ##
  ## Returns the filename of the created file.
  let audioContent = await synthesize(client, input, voice, audioConfig)
  let hashed = $hash($input & voice.name.get(""))
  result = folder / "tts" & (
    case audioConfig.audioEncoding
    of LINEAR16:
      hashed.addFileExt("wav")
    of MP3:
      hashed.addFileExt("mp3")
    of OGG_OPUS:
      hashed.addFileExt("ogg")
  )
  writeFile(result, audioContent)

when isMainModule:
  let client = newTextToSpeechClient()
  let filename =
    client.synthesizeToFolder(
      "Have you ever felt the cold, determined, voice of a machine?",
      getCurrentDir(),
      voice=initVoiceSelectionParams(name=some("en-GB-Wavenet-D")),
      audioConfig=initAudioConfig(audioEncoding=OGG_OPUS, pitch=20))
  echo filename