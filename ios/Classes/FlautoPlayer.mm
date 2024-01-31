/*
 * Copyright 2018, 2019, 2020, 2021 Dooboolab.
 *
 * This file is part of Flutter-Sound.
 *
 * Flutter-Sound is free software: you can redistribute it and/or modify
 * it under the terms of the Mozilla Public License version 2 (MPL2.0),
 * as published by the Mozilla organization.
 *
 * Flutter-Sound is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * MPL General Public License for more details.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */


#import <AVFoundation/AVFoundation.h>


#import "Flauto.h"
#import "FlautoPlayerEngine.h"
#import "FlautoPlayer.h"


static bool _isIosDecoderSupported [] =
{
		true, // DEFAULT
		true, // aacADTS
		false, // opusOGG
		true, // opusCAF
		true, // MP3
		false, // vorbisOGG
		false, // pcm16
		true, // pcm16WAV
		true, // pcm16AIFF
		true, // pcm16CAF
		true, // flac
		true, // aacMP4
                false, // amrNB
                false, // amrWB
                false, //pcm8,
                false, //pcmFloat32,
                false, // pcmWebM
                false, // opusWebM
                false, // vorbisWebM


};


//-------------------------------------------------------------------------------------------------------------------------------

@implementation FlautoPlayer
{
        NSTimer* timer;
        double subscriptionDuration;
        double latentVolume;
        double latentSpeed;
        long latentSeek;
        bool voiceProcessing;

}

- (FlautoPlayer*)init: (NSObject<FlautoPlayerCallback>*) callback
{
        m_callBack = callback;
        latentVolume = -1.0;
        latentSpeed = -1.0;
        latentSeek = -1;
        subscriptionDuration = 0;
        timer = nil;

        printf("baikal_flutter_sound_core_player init\n");
        return [super init];
}

- (void)setVoiceProcessing: (bool) enabled
{
        voiceProcessing = enabled;
}

- (bool)isVoiceProcessingEnabled
{
        return voiceProcessing;
}


- (t_PLAYER_STATE)getPlayerState
{
        if ( m_playerEngine == nil )
                return PLAYER_IS_STOPPED;
        return [m_playerEngine getStatus];
}



- (bool)isDecoderSupported: (t_CODEC)codec
{
        return _isIosDecoderSupported[codec];
}




- (void)releaseFlautoPlayer
{
        [self logDebug: @"baikal_iOS::--> releaseFlautoPlayer"];
        printf("print_baikal_iOS::--> releaseFlautoPlayer\n");

        [ self stop];
        [m_callBack closePlayerCompleted: YES];
        [self logDebug:  @"baikal_iOS::<-- releaseFlautoPlayer"];
        printf("print_baikal_iOS::<-- releaseFlautoPlayer\n");
}


- (void)stop
{
        [self stopTimer];
        if ( ([self getStatus] == PLAYER_IS_PLAYING) || ([self getStatus] == PLAYER_IS_PAUSED) )
        {
                [self logDebug:  @"baikal_iOS:: ![audioPlayer stop]"];
                printf("print_baikal_iOS:: ![audioPlayer stop]\n");
                [m_playerEngine stop];
        }
        m_playerEngine = nil;

}


- (void)stopPlayer
{
        [self logDebug:  @"baikal_iOS::--> stopPlayer"];
        printf("print_baikal_iOS::--> stopPlayer\n");
        [self stop];
        [m_callBack stopPlayerCompleted: YES];
        [self logDebug:  @"baikal_iOS::<-- stopPlayer"];
        printf("print_baikal_iOS::<-- stopPlayer\n");

}

- (bool)startPlayerFromMicSampleRate: (long)sampleRate nbChannels: (int)nbChannels
{
        [self logDebug:  @"baikal_iOS::--> startPlayerFromMicSampleRate"];
        printf("print_baikal_iOS::--> startPlayerFromMicSampleRate\n");
        [self stop]; // To start a fresh new playback
        m_playerEngine = [[AudioEngineFromMic alloc] init: self ];
        [m_playerEngine startPlayerFromURL: nil codec: (t_CODEC)0 channels: nbChannels sampleRate: sampleRate];
        bool b = [m_playerEngine play];
        if (b)
        {
                        [ m_callBack startPlayerCompleted: true duration: 0];
        }
        [self logDebug:  @"baikal_iOS::<-- startPlayerFromMicSampleRate"];
        printf("print_baikal_iOS::<-- startPlayerFromMicSampleRate\n");
        return b; // TODO
}



- (NSString*) getpath:  (NSString*)path
{
         if ((path == nil)|| ([path class] == [[NSNull null] class]))
                return nil;
        if (![path containsString: @"/"]) // Temporary file
        {
                path = [NSTemporaryDirectory() stringByAppendingPathComponent: path];
        }
        return path;
}

- (NSString*) getUrl: (NSString*)path
{
         if ((path == nil)|| ([path class] == [[NSNull null] class]))
                return nil;
        path = [self getpath: path];
        NSURL* url = [NSURL URLWithString: path];
        return [url absoluteString];
}


- (bool)startPlayerCodec: (t_CODEC)codec
        fromURI: (NSString*)path
        fromDataBuffer: (NSData*)dataBuffer
        channels: (int)numChannels
        sampleRate: (long)sampleRate
{
        [self logDebug:  @"baikal_iOS::--> startPlayer"];
        printf("print_baikal_iOS::--> startPlayer\n");
        bool b = FALSE;
        [self stop]; // To start a fresh new playback

        if ( (path == nil ||  [path class] == [NSNull class] ) && codec == pcm16)
                m_playerEngine = [[AudioEngine alloc] init: self ];
        else
                m_playerEngine = [[AudioPlayerFlauto alloc]init: self];
        
        if (dataBuffer != nil)
        {
                [m_playerEngine startPlayerFromBuffer: dataBuffer];
                bool b = [self play];

                if (!b)
                {
                        [self stop];
                } else
                {

                        [self startTimer];
                        long duration = [m_playerEngine getDuration];
                        [ m_callBack startPlayerCompleted: true duration: duration];
                }
                [self logDebug:  @"baikal_iOS::<-- startPlayer]"];
                printf("print_baikal_iOS::<-- startPlayer]\n");

                return b;
        }
        path = [self getpath: path];
        bool isRemote = false;

        if (path != (id)[NSNull null])
        {
                NSURL* remoteUrl = [NSURL URLWithString: path];
                NSURL* audioFileURL = [NSURL URLWithString:path];

                if (remoteUrl && remoteUrl.scheme && remoteUrl.host)
                {
                        audioFileURL = remoteUrl;
                        isRemote = true;
                }

                  if (isRemote)
                  {
                        NSURLSessionDataTask *downloadTask = [[NSURLSession sharedSession]
                                dataTaskWithURL:audioFileURL completionHandler:
                                ^(NSData* data, NSURLResponse *response, NSError* error)
                                {

                                        // We must create a new Audio Player instance to be able to play a different Url
                                        //int toto = data.length;
                                        [self ->m_playerEngine startPlayerFromBuffer: data ];
                                        bool b = [self play];

                                        if (!b)
                                        {
                                                [self stop];
                                        } else
                                        {
                                                [self startTimer];
                                                long duration = [self ->m_playerEngine getDuration];
                                                [ self ->m_callBack startPlayerCompleted: true duration: duration];
                                        }
                                }];

                        [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
                        [downloadTask resume];
                        [self logDebug:  @"baikal_iOS::<-- startPlayer"];
                        printf("print_baikal_iOS::<-- startPlayer\n");

                        return true;

                } else
                {
                        [m_playerEngine startPlayerFromURL: audioFileURL codec: codec channels: numChannels sampleRate: sampleRate ];
                }
        } else
        {
                [m_playerEngine startPlayerFromURL: nil codec: codec channels: numChannels sampleRate: sampleRate ];
        }
        b = [self play];

        if (b)
        {
                 [self startTimer];
                long duration = [m_playerEngine getDuration];
                [ m_callBack startPlayerCompleted: true duration: duration];
        }
        [self logDebug: @"baikal_iOS::<-- startPlayer"];
        printf("print_baikal_iOS::<-- startPlayer\n");
        return b;
}

- (bool) play
{
        if (latentVolume >= 0)
                [self setVolume: latentVolume fadeDuration: 0];
        if (latentSpeed >= 0)
        {
                [self setSpeed: latentSpeed] ;
        }
        if (latentSeek >= 0)
        {
                [self seekToPlayer: latentSeek] ;
        }
        
        return  [m_playerEngine play];

}

- (void)needSomeFood: (int)ln
{
        dispatch_async(dispatch_get_main_queue(),
        ^{
                [self ->m_callBack needSomeFood: ln];
         });
}

- (void)updateProgress: (NSTimer*)atimer
{
                long position = [self ->m_playerEngine getPosition];
                long duration = [self ->m_playerEngine getDuration];
                [self ->m_callBack updateProgressPosition: position duration: duration];
}


- (void)startTimer
{
        [self logDebug:  @"baikal_iOS::--> startTimer"];
        printf("print_baikal_iOS::--> startTimer\n");

        [self stopTimer];
        if (subscriptionDuration > 0)
        {
                dispatch_async(dispatch_get_main_queue(),
                ^{ // ??? Why Async ?  (no async for recorder)
                        self ->timer = [NSTimer scheduledTimerWithTimeInterval: self ->subscriptionDuration
                                                   target:self
                                                   selector:@selector(updateProgress:)
                                                   userInfo:nil
                                                   repeats:YES];
                });
        }
        [self logDebug:  @"baikal_iOS::<-- startTimer"];
        printf("print_baikal_iOS::<-- startTimer\n");

}


- (void) stopTimer
{
        [self logDebug:  @"baikal_iOS::--> stopTimer"];
        printf("print_baikal_iOS::--> stopTimer\n");

        if (timer != nil) {
                [timer invalidate];
                timer = nil;
        }
        [self logDebug:  @"baikal_iOS::<-- stopTimer"];
        printf("print_baikal_iOS::<-- stopTimer\n");
}



- (bool)pausePlayer
{
        [self logDebug:  @"baikal_iOS::--> pausePlayer"];
        printf("print_baikal_iOS::--> pausePlayer\n");

 
        if (timer != nil)
        {
                [timer invalidate];
                timer = nil;
        }
        if ([self getStatus] == PLAYER_IS_PLAYING )
        {
                  /*
                  long position =   [m_playerEngine getPosition];
                  long duration =   [m_playerEngine getDuration];
                  if (duration - position < 200) // PATCH [LARPOUX]
                  {
                        [self logDebug:  @"baikal_iOS:: !patch [LARPOUX]"];
                        dispatch_async(dispatch_get_main_queue(),
                        ^{
                                [self stop];
                                [self logDebug:  @"baikal_iOS::--> ^audioPlayerFinishedPlaying"];

                                [self ->m_callBack  audioPlayerDidFinishPlaying: true];
                                [self logDebug:  @"baikal_iOS::<-- ^audioPlayerFinishedPlaying"];
                         });
                        //return false;
                  } else
                  */

                        [m_playerEngine pause];
        }
        else
                [self logDebug:  @"baikal_iOS:: audioPlayer is not Playing"];
                printf("print_baikal_iOS:: audioPlayer is not Playing\n");

          [m_callBack pausePlayerCompleted: YES];
          [self logDebug:  @"baikal_iOS::<-- pause"];
          printf("print_baikal_iOS::<-- pause\n");

          return true;

}






- (bool)resumePlayer
{
        [self logDebug:  @"baikal_iOS::--> resumePlayer"];
        printf("print_baikal_iOS::--> resumePlayer\n");
        bool b = [m_playerEngine resume];
        if (!b){}
        
            
        [self startTimer];
        [self logDebug:  @"baikal_iOS::<-- resumePlayer"];
        printf("print_baikal_iOS::<-- resumePlayer\n");

        [m_callBack resumePlayerCompleted: b];
        return b;
}





- (int)feed:(NSData*)data
{
		try
		{
                        int r = [m_playerEngine feed: data];
			return r;
		} catch (NSException* e)
		{
                        return -1;
  		}

}




- (void)seekToPlayer: (long)t
{
        [self logDebug: @"baikal_iOS::--> seekToPlayer"];
        printf("print_baikal_iOS::--> seekToPlayer\n");
        if (m_playerEngine != nil)
        {
                latentSeek = -1;
                [m_playerEngine seek: t];
                [self updateProgress: nil];
        } else
        {
                latentSeek = t;
        }
        [self logDebug:  @"baikal_iOS::<-- seekToPlayer"];
        printf("print_baikal_iOS::<-- seekToPlayer\n");
}



- (void)setVolume:(double) volume fadeDuration:(NSTimeInterval)duration // volume is between 0.0 and 1.0
{
        [self logDebug:  @"baikal_iOS::--> setVolume"];
        printf("print_baikal_iOS::--> setVolume\n");
        latentVolume = volume;
        if (m_playerEngine)
        {
                [m_playerEngine setVolume: volume fadeDuration: duration];
        } else
        {
        }
        [self logDebug: @"baikal_iOS::<-- setVolume"];
        printf("print_baikal_iOS::<-- setVolume\n");
}


- (void)setSpeed:(double) speed // speed is between 0.0 and 1.0 to slow and 1.0 to n to accelearate
{
        [self logDebug:  @"baikal_iOS::--> setSpeed"];
        printf("print_baikal_iOS::--> setSpeed\n");
        latentSpeed = speed;
        if (m_playerEngine )
        {
                [m_playerEngine setSpeed: speed ];
        } else
        {
        }
        [self logDebug: @"baikal_iOS::<-- setSpeed"];
        printf("print_baikal_iOS::<-- setSpeed\n");
}



- (long)getPosition
{
        return [m_playerEngine getPosition];
}

- (long)getDuration
{
         return [m_playerEngine getDuration];
}


- (NSDictionary*)getProgress
{
        [self logDebug:  @"baikal_iOS::--> getProgress"];
        printf("print_baikal_iOS::--> getProgress\n");

        NSNumber *position = [NSNumber numberWithLong: [m_playerEngine getPosition]];
        NSNumber *duration = [NSNumber numberWithLong: [m_playerEngine getDuration]];
        NSDictionary* dico = @{ @"position": position, @"duration": duration, @"playerStatus": [self getPlayerStatus] };
        [self logDebug:  @"baikal_iOS::<-- getProgress"];
        printf("print_baikal_iOS::<-- getProgress\n");
        return dico;

}


- (void)setSubscriptionDuration: (long)d
{
        [self logDebug:  @"baikal_iOS::--> setSubscriptionDuration"];
        printf("print_baikal_iOS::--> setSubscriptionDuration\n");

        subscriptionDuration = ((double)d)/1000;
        if (m_playerEngine != nil)
        {
                [self startTimer];
        }
        [self logDebug:  @"baikal_iOS::<-- setSubscriptionDuration"];
        printf("print_baikal_iOS::<-- setSubscriptionDuration\n");

}


// post fix with _FlutterSound to avoid conflicts with common libs including path_provider
- (NSString*) GetDirectoryOfType_FlutterSound: (NSSearchPathDirectory) dir
{
        NSArray* paths = NSSearchPathForDirectoriesInDomains(dir, NSUserDomainMask, YES);
        return [paths.firstObject stringByAppendingString:@"/"];
}


- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)thePlayer successfully:(BOOL)flag
{
        [self logDebug:  @"baikal_iOS::--> @audioPlayerDidFinishPlaying"];
        printf("print_baikal_iOS::--> @audioPlayerDidFinishPlaying\n");

        dispatch_async(dispatch_get_main_queue(), ^{
                [self stopTimer];
                [ self ->m_playerEngine stop];
                self ->m_playerEngine = nil;
                [self logDebug:  @"baikal_iOS::--> ^audioPlayerFinishedPlaying"];
                printf("print_baikal_iOS::--> ^audioPlayerFinishedPlaying\n");

                [self ->m_callBack  audioPlayerDidFinishPlaying: true];
                [self logDebug:  @"baikal_iOS::<-- ^audioPlayerFinishedPlaying"];
                printf("print_baikal_iOS::<-- ^audioPlayerFinishedPlaying\n");
         });
 
         [self logDebug:  @"baikal_iOS::<-- @audioPlayerDidFinishPlaying"];
         printf("print_baikal_iOS::<-- @audioPlayerDidFinishPlaying\n");
}

- (t_PLAYER_STATE)getStatus
{
        if ( m_playerEngine == nil )
                return PLAYER_IS_STOPPED;
        return [m_playerEngine getStatus];
}

- (NSNumber*)getPlayerStatus
{
        return [NSNumber numberWithInt: [self getStatus]];
}


- (void)logDebug: (NSString*)msg
{
        [m_callBack log: DBG msg: msg];
}


@end
//---------------------------------------------------------------------------------------------

