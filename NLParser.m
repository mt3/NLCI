//
//  NLParser.m
//  NL_interface
//
//  Created by Alejandro Ciniglio on 11/23/09.
//  Copyright 2009 Princeton University. All rights reserved.
//

#import "NLParser.h"


@implementation NLParser

@synthesize raw;
@synthesize action;
@synthesize directObject;
@synthesize preposition;
@synthesize indirectObject;

@synthesize actionLocation;
@synthesize directObjectLocation;

-(id)initWithRaw:(NSString *)rawInput withPossibleNouns:(NSMutableArray *)pNouns{
	self = [super init];
	if (self) {
		raw = [rawInput lowercaseString];
		nounSynonyms = nil;
		possibleNouns = pNouns;
		actionLocation = -1;
		action = nil;
		actionRemainder = nil;
		verb = nil;
		directObjectLocation = -1;
		directObject = nil;
		prepositionLocation = -1;
		preposition = nil;
		indirectObjectLocation = -1;
		indirectObject = nil;
		NSLog(@"NLParser initialized w/ raw: %@", raw);
	}
	return self;
}

// Helper method to make strings uniform (we are assuming unique strings anyways, so lowercase is fine)
-(NSString *)makeLowercaseAndPunctuationFree:(NSString *)ugly {
        NSString *up = [[ugly componentsSeparatedByCharactersInSet:[[NSCharacterSet letterCharacterSet] invertedSet]] componentsJoinedByString:@" "];
        NSString *spaced = [up stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSString *pretty = [spaced lowercaseString];
	return pretty;
}

-(float)actionProbable{
        int correct = 0;
	NSArray *parts = [[self makeLowercaseAndPunctuationFree:action] componentsSeparatedByString:@" "];
	int possible = [parts count];
	for (NSString *part in parts){
	         //
        	 NSRange range = [raw rangeOfString:part];
		 if (range.location != NSNotFound) {
		   correct++;
		 }
        }
	return ((float) correct) / ((float) possible);
}

// Method that scores the similiarity of a string to $raw
// Based on number of matched words as well as the percentage of raw that is correctly matched
-(float)getMatchScoreUsing:(NSString *)match {
        int correct = 0;
        int rawTotal = [[raw componentsSeparatedByString:@" "] count];
	int matchTotal = [[match componentsSeparatedByString:@" "] count];
        NSArray *parts = [[self makeLowercaseAndPunctuationFree:match] componentsSeparatedByString:@" "];
	for (NSString *part in parts){
                 //NSLog(@"Scoring %@", part);
                 NSRange range = [raw rangeOfString:part];
                 if (range.location != NSNotFound) {
                   //      NSLog(@"Found: %@", part);
                   correct++;
                 }
        }
        return ((float) correct) / (((float) rawTotal + (float) matchTotal));
}

// Here, given a preposition for a verb, will try to find it in $raw
-(void *)findAndSetPreposition{
        NSString *prep = [self getPrepositionIfAny];
	if ([prep length] == 0)
	  return;
        NSRange range = [raw rangeOfString:prep];
        if (range.location != NSNotFound) {
                preposition = prep;
              	prepositionLocation = range.location;
        }
}

// Given an action string, will find the preposition if one is attached
// e.g. Open With... returns @"with"
-(NSString *)getPrepositionIfAny {
        NSString *cleanAction = [self makeLowercaseAndPunctuationFree:action];
    	NSArray *cleanParts = [cleanAction componentsSeparatedByString:@" "];
	if ([cleanParts count] == 1)
	  return @"";
        NSString *prep = [cleanParts objectAtIndex:[cleanParts count] - 1];
        return prep;
}

// Searches through a given array to find most likely action in raw, 
// using the scoring function from above
-(int)getMostLikelyActionFromActions:(NSArray *)actions {
	int min = NSIntegerMax;
	float bestScore = 0;
	int i,ret;
   
	NSLog(@"ActionCount: %d", [actions count]);
	// iterate through each possible action
	for (i=0;i < [actions count]; i++){
                NSString *actName = [actions objectAtIndex:i];
	        NSString *act = [self makeLowercaseAndPunctuationFree:actName];
		NSArray *actionParts = [act componentsSeparatedByString:@" "];
		NSString *mainAct = [actionParts objectAtIndex:0]; // assumes the verb is the first word in the action
		NSRange range = [raw rangeOfString:mainAct];
		if ([self getMatchScoreUsing:act] > bestScore && range.location != NSNotFound) {
		        if (range.location <= min){
        			ret = i;
				action = actName;
				verb = mainAct;
				min = range.location;
				actionLocation = min;	
				bestScore = [self getMatchScoreUsing:act];
				actionRemainder = [self cleanupWhitespaceIn:[raw substringFromIndex:(min + [mainAct length])]];
			}
		}
	}
	NSLog(@"ActionLocation : %d", actionLocation);
	NSLog(@"Action remainder: %@", actionRemainder);
	if ([self actionProbable] > .7)
	        return ret;
	return -1;
}

// Removes trailing and leading whitespace
- (NSString *)cleanupWhitespaceIn:(NSString *)str {
	NSArray *arr = [str componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	NSMutableArray *ret = [NSMutableArray array];
	for(NSString *comp in arr){
		if ([comp length] > 0) {
			[ret addObject:comp];
		}
	}
	return [ret componentsJoinedByString:@" "];
}

// finds the given objects on either side of the preposition
- (void)setObjectsWithIndirect:(BOOL)indirect {
	if (indirect) {
		if (prepositionLocation > 0) {
			NSArray *rawArray = [raw componentsSeparatedByString:@" "];
			NSRange doRange;
			doRange.location = actionLocation + [[[action componentsSeparatedByString:@" "] objectAtIndex:0] length];
			doRange.length = prepositionLocation - doRange.location;
			directObject = [self cleanupWhitespaceIn:[raw substringWithRange:doRange]];//[[rawArray subarrayWithRange:doRange] componentsJoinedByString:@""];
			directObjectLocation = doRange.location + 1;
			
			NSRange ioRange;
			ioRange.location = prepositionLocation + [preposition length];
			ioRange.length = [raw length] - ioRange.location;
			indirectObject = [self cleanupWhitespaceIn:[raw substringWithRange:ioRange]];
			indirectObjectLocation = ioRange.location + 1;
		}
	
		else {
		// NSRange doRange;
		// doRange.location = actionLocation + [[self makeLowercaseAndPunctuationFree:action] length];
		// doRange.length = [[self makeLowercaseAndPunctuationFree:raw] length] -
		//                  [[self makeLowercaseAndPunctuationFree:action] length];
		// directObject = [self cleanupWhitespaceIn:[raw substringWithRange:doRange]];
		// directObjectLocation = doRange.location + 1;
		  NSLog(@"No preposition");
		  [self doubleObjectParser];
		}
	}
	else {
	  directObject = [self nounMatch:[self cleanupWhitespaceIn:actionRemainder]];
	  directObjectLocation = actionLocation + [[[action componentsSeparatedByString:@" "] objectAtIndex:0] length] + 1;
	}

}

- (NSString *)nounMatch:(NSString *)n{
  /*FIND NOUN

stirng [] nouns
dictionary n_synonyms

given n
if n in nouns:
   return n
if n in n_synonyms.keys:
   return n_synonyms[n]
   error "$n not found" */
        for(NSString *noun in possibleNouns){
	        noun = [noun lowercaseString];
	        if ([n isEqualToString:noun]) return noun;
		}
	//	if ([nounSynonyms valueForKey:n]) return [nounSynonyms valueForKey:n];
	return @"";


}

- (BOOL)doubleObjectParser{
  /*        OBJECT MATCHING / FINDING

	    VERB OBJ1a OBJ1b OBJ2a

	    for words in sentence:
	        verb, remainder = findverb
		if (preposition in remainder):
		    easycase (find DO and IO)
		else:
	            len := remainder.words.length	
		    for i=1 ; i<len ; i++
       		        if (match(remainder.words[:i]) AND match(remainder.words[i:]))
        		    got DO and IO
			    doit
			    found = true
			    break
		    if (!found) error "please specify more stuff"
*/
        NSArray *inWords = [actionRemainder componentsSeparatedByString:@" "];
	int len = [[actionRemainder componentsSeparatedByString:@" "] length];
	int i = 0; int j = 0;
	NSMutableString *part1 = [[NSMutableString alloc] initWithString:@""];
	NSMutableString *part2 = [[NSMutableString alloc] initWithString:@""];
	for (i = 0; i < len; i++){
	     [part1 appendString:(@" %@", [inWords objectAtIndex:i])];
		 part1 = [self cleanupWhitespaceIn:part1];
	}
	     part2 = @"";
	     for (j = i; j < len; j++){
	         [part2 appendString:(@" %@", [inWords objectAtIndex:j])];
	         part2 = [self cleanupWhitespaceIn:part2];
	     }
	     if ([[self nounMatch:part1] length] && [[self nounMatch:part2] length]){
	              part1 = [self nounMatch:part1];
		      part2 = [self nounMatch:part2];
	              directObject = part2;
		      indirectObject = part1;
		      return YES;
	     }
	
	return NO;
	

}//
//
//- (BOOL)nSynonymous:(NSString *)p1 with:(NSString *)p2 {
//  /*     SYNONYMS:
//
//N1 is N2
//
//global dictionary n_synonyms
//global array Nouns
//
//for words in sentence:
//    if (word == is)
//        assignment = true;
//	break;
//
//part1 = sentence.split("is")[0]
//part2 = sentence.split("is")[1]
//
//if part1 in nouns:
//   n_synonyms[part2] = part1
//else if part2 in nouns:
//   n_synonyms[part1] = part2
//else if part1 in synonyms.keys():
//   n_synonyms[part1] = part2
//else if part2 in synonyms.keys():
//   n_synonyms[part2] = part1
//else: 
//   error("I don't know what $part1 or $part2 are")
//   return;
//n_synonyms.save()
//	*/
//
//  BOOL p1Main, p2Main;
//  for (NSString *noun in possibleNouns){
//    if (p1 == noun)
//      p1Main = YES;
//    if (p2 == noun)
//      p2Main = YES;
//  }
//  if (p1Main && p2Main)
//    //error
//    return YES;
//  if (p1Main) {
//    [nSynonyms setObject:p1 forKey:p2];
//    return YES;
//  }
//  else if (p2Main) {
//    [nSynonyms setObject:p2 forKey:p1];
//  }
//  for (NSString *key in [nSynonyms allKeys]){
//    if (p1 == key){
//      [nSynonyms setObject:p2 forKey:p1];
//      return YES;
//    }
//    if (p2 == key){
//      [nSynonyms setObject:p1 forKey:p2];
//      return YES;
//    }
//  }
//  return NO;
//
//}
//
//
@end