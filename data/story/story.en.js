/* DEADLINE 15 — Story script (English translation)
 * Format: docs/story-schema.md
 * Narrative setting: docs/STORY.md
 * {commander} is replaced with the player commander's name. Never use gendered pronouns for the commander.
 */
window.STORY_EN = {
  cast: {
    commander: { name: 'Lian', portrait: 'commander', role: 'Protagonist · Clan Commander' },
    narrator:  { name: '', portrait: null },
    bram:  { name: 'Bram',   portrait: 'story/bram',  fallback: 'knight_01',   role: 'Old knight · Militia drillmaster, the Commander\'s mentor' },
    sera:  { name: 'Sera',   portrait: 'story/sera',  fallback: 'priest_02',   role: 'Clan healer · The Commander\'s childhood friend' },
    bark:  { name: 'Bark',   portrait: 'story/bark',  fallback: 'brawler_01',  role: 'Ex-bandit · Clan vanguard captain' },
    kasha: { name: 'Kasha',   portrait: 'story/kasha', fallback: 'assassin_02', role: 'Leader of the Black Feather mercenaries · Rival' },
    ordin: { name: 'Ordin', portrait: 'story/ordin', fallback: 'summoner_01', role: 'Royal Archmage · The clan\'s patron' },
    fake_bram: { name: 'Bram?', portrait: 'story/bram', fallback: 'knight_01', ghost: true, role: 'An illusion wearing Bram\'s face (s70)' },
  },

  episodes: {
    1: { title: 'The Hero\'s Beginning',
      prologue: [
        { who: 'narrator', text: 'Fifteen years ago came the Night the Sky Split.' },
        { who: 'narrator', text: 'A violet rift opened, then closed before dawn.' },
        { who: 'narrator', text: 'In the wreckage of that night, a child was found.' },
        { who: 'narrator', text: 'On one palm was a scar shaped like a split star.' },
        { who: 'narrator', text: 'And now: Solbit Village, on the frontier.' },
        { who: 'bram', text: 'The militia captain fell to a bandit arrow. We need a new commander.' },
        { who: 'commander', text: 'Why me? Plenty of members have served longer.' },
        { who: 'bram', text: 'You read the ground before you fight. That\'s a commander\'s eye.' },
        { who: 'sera', text: '{commander}, I\'m coming too. If you get hurt, I\'ll fix you up.' },
        { who: 'commander', text: '...Understood. I won\'t lose a single person.' },
        { who: 'bram', text: 'Good resolve, kid. Now keep that promise to the end.' },
        { who: 'bram', text: 'Take this. The silver baton I carried on the kingdom\'s battlefields.' },
        { who: 'commander', text: 'A baton? Not a sword?' },
        { who: 'bram', text: 'A commander doesn\'t stand up front swinging a blade.' },
        { who: 'bram', text: 'Read the field from the rear. Signal with this.' },
        { who: 'bram', text: 'Your weapon is your clan members. Just give clear orders.' },
      ],
      epilogue: [
        { who: 'narrator', text: 'The bandits fell, and bells rang out over Solbit Village.' },
        { who: 'narrator', text: 'Three days later, a carriage flying royal banners rolled in.' },
        { who: 'ordin', text: 'I am Ordin, Royal Archmage. You must be that commander.' },
        { who: 'ordin', text: 'The north is freezing. The Crown has need of your clan.' },
        { who: 'commander', text: 'We\'re just a village militia.' },
        { who: 'ordin', text: 'A militia that broke a hundred bandits will suffice.' },
        { who: 'ordin', text: '...That scar on your hand. How long have you carried it?' },
        { who: 'commander', text: 'As long as I can remember. Why?' },
        { who: 'ordin', text: 'No reason. Merely curious.' },
        { who: 'bram', text: '(That look... I\'ve seen it before. Fifteen years ago.)' },
        { who: 'narrator', text: 'With a royal commission in hand, the clan set out north.' },
      ] },

    2: { title: 'The Frozen Conspiracy',
      prologue: [
        { who: 'narrator', text: 'The Snowveil Mountains of the north. Snow that never melts.' },
        { who: 'narrator', text: 'This year, even the villages below froze overnight.' },
        { who: 'bark', text: 'Boss, just breathing up here freezes my nose hairs.' },
        { who: 'sera', text: 'The frozen dead... they all look like they saw something.' },
        { who: 'bram', text: 'This is no natural cold. Someone summoned it.' },
        { who: 'commander', text: '(The scar on my palm... it throbs, ice-cold.)' },
        { who: 'commander', text: 'First we protect the villages below. The cause comes after.' },
      ],
      epilogue: [
        { who: 'narrator', text: 'When the Frost Knight fell, a spring wind swept the mountains.' },
        { who: 'bram', text: 'Halvar... an old comrade. He was there that same night, fifteen years ago.' },
        { who: 'commander', text: 'His last words. What was he saying about the Archmage?' },
        { who: 'bram', text: 'I don\'t know. Don\'t speak of it until we\'re sure.' },
        { who: 'kasha', text: 'You beat me to it again, country commander.' },
        { who: 'kasha', text: 'But remember: the Black Feather never loses twice.' },
        { who: 'narrator', text: 'Just then, an urgent messenger arrived from the capital.' },
        { who: 'ordin', text: 'A plague is spreading in the southern marsh. Make haste, I beg you.' },
        { who: 'commander', text: '...It\'s like he knows where the next disaster will strike.' },
      ] },

    3: { title: 'The Curse of the Swamp',
      prologue: [
        { who: 'narrator', text: 'Blackwater Marsh in the south. Coughing echoed through the mist.' },
        { who: 'narrator', text: 'Beasts, twisted out of shape, fell upon the people.' },
        { who: 'sera', text: 'Plague is my job. This time, I\'ll take the lead.' },
        { who: 'commander', text: 'Sera, don\'t try to carry it all alone.' },
        { who: 'bark', text: 'A mud fight? That\'s my specialty!' },
        { who: 'bram', text: 'Shallows bog your feet. Get hit there and it hurts more.' },
        { who: 'commander', text: 'Nobody stands in the shallows carelessly. Remember that.' },
      ],
      epilogue: [
        { who: 'narrator', text: 'As the Lord of the Marsh sank, the water slowly cleared.' },
        { who: 'commander', text: 'This map... the north, the marsh, and the empire\'s volcano.' },
        { who: 'bram', text: 'Connect the three and you get a triangle. A massive formation.' },
        { who: 'sera', text: 'Someone\'s been causing these disasters one by one, on purpose.' },
        { who: 'ordin', text: 'I have received your report. The Volkar Empire is surely behind this.' },
        { who: 'commander', text: 'We found ritual vessels bearing the royal crest in the temple.' },
        { who: 'ordin', text: 'The Empire sought to frame us, no doubt. March forth.' },
        { who: 'bram', text: '(He answered too fast.)' },
        { who: 'narrator', text: 'Doubts unspoken, the clan crossed the border.' },
      ] },

    4: { title: 'The Burning Empire',
      prologue: [
        { who: 'narrator', text: 'The Volkar Empire. A land of steel, forged in volcanic fire.' },
        { who: 'narrator', text: 'Now it burned, torn between loyalists and rebels.' },
        { who: 'bark', text: 'If the Empire\'s really behind it, we just take the emperor\'s head.' },
        { who: 'bram', text: 'I wish it were that simple.' },
        { who: 'sera', text: 'Children are crying in the burned villages. They come first.' },
        { who: 'commander', text: 'We join the rebels. These people aren\'t our enemy.' },
      ],
      epilogue: [
        { who: 'narrator', text: 'The Flame Emperor fell, and the volcano\'s red sky cooled.' },
        { who: 'commander', text: 'The emperor\'s last words. The letter on the altar. It\'s all Ordin.' },
        { who: 'bram', text: '"Feed the flames as promised." Now we\'re sure.' },
        { who: 'kasha', text: 'So your patron set up this whole game.' },
        { who: 'commander', text: 'I\'m going to the capital to ask him myself. Why he did this.' },
        { who: 'narrator', text: 'But that night, the earth split open as if screaming.' },
        { who: 'narrator', text: 'In the western wastes, a bottomless pit opened: the Abyss.' },
        { who: 'sera', text: 'Monsters are pouring out of it. The villages are in danger!' },
        { who: 'bram', text: 'The truth won\'t run away. Lives won\'t wait.' },
        { who: 'commander', text: '...We go to the Abyss. Ordin can wait.' },
      ] },

    5: { title: 'The End of the Abyss',
      prologue: [
        { who: 'narrator', text: 'The Abyss. Ruins of an ancient civilization, asleep beneath the earth.' },
        { who: 'narrator', text: 'Down where no light reached, something was waking.' },
        { who: 'bark', text: 'Can\'t see the bottom. Fall in, and that\'s it for good.' },
        { who: 'sera', text: 'The air\'s heavy. It feels like my prayers can\'t get through.' },
        { who: 'bram', text: 'Commander. This time, someone might not come back.' },
        { who: 'commander', text: 'Don\'t say that. We\'re all coming back.' },
        { who: 'bram', text: 'Right. That stubbornness is your strength.' },
        { who: 'commander', text: '(The scar is burning. Someone down there is calling me.)' },
      ],
      epilogue: [
        { who: 'narrator', text: 'The Abyssal Warrior fell, and the rumbling from the depths faded.' },
        { who: 'narrator', text: 'The clan returned to the surface. Leaving one behind.' },
        { who: 'narrator', text: 'On the hill above Solbit Village, an empty coffin was buried.' },
        { who: 'sera', text: 'Uncle Bram... was smiling, right to the end.' },
        { who: 'commander', text: 'I said we\'d all come back. I said that.' },
        { who: 'bark', text: 'Not your fault, boss. The old man chose that spot himself.' },
        { who: 'kasha', text: 'No time to grieve. Ordin\'s vanished from the capital.' },
        { who: 'kasha', text: 'And in the sky north of the capital... a gate is forming.' },
        { who: 'commander', text: '...Let\'s go. To protect what Bram was protecting.' },
      ] },

    6: { title: 'Hell\'s Gate',
      prologue: [
        { who: 'narrator', text: 'Cracks spread across the sky. Just like that night fifteen years ago.' },
        { who: 'narrator', text: 'But this time, they did not close at dawn.' },
        { who: 'narrator', text: 'North of the capital, a colossal gate was slowly opening.' },
        { who: 'sera', text: '{commander}, you haven\'t been sleeping. Are you okay?' },
        { who: 'commander', text: 'No. But if I stop, we lose even more.' },
        { who: 'commander', text: 'Bram said a commander can\'t save everyone.' },
        { who: 'commander', text: 'But we can refuse to abandon anyone.' },
        { who: 'narrator', text: 'The broken sword tucked away, the silver baton rose once more.' },
        { who: 'bark', text: 'Been waiting to hear that, boss. Let\'s go again.' },
      ],
      epilogue: [
        { who: 'narrator', text: 'The moment the Warden fell, the Hell Gate swung wide open.' },
        { who: 'ordin', text: 'Well done, young commander. Nay... O Key.' },
        { who: 'commander', text: 'Ordin! So this was your plan all along!' },
        { who: 'ordin', text: 'Only your blood could fell the Warden.' },
        { who: 'ordin', text: 'Fifteen years ago, your parents closed the gate. With their lives.' },
        { who: 'ordin', text: 'I must open it. To call upon a god.' },
        { who: 'narrator', text: 'Ordin vanished into the red darkness beyond the gate.' },
        { who: 'kasha', text: 'You\'re going after him, right? Your face says you\'ve decided.' },
        { who: 'commander', text: 'We go through the gate. This time, we end it.' },
      ] },

    7: { title: 'Demonic Realm',
      prologue: [
        { who: 'narrator', text: 'The Demon Realm. The sky blood-red, the ground breathing.' },
        { who: 'narrator', text: 'Here the paths changed daily, and memories took form.' },
        { who: 'bark', text: 'That rock just looked at me. I swear.' },
        { who: 'sera', text: 'I don\'t think we can trust everything we see here.' },
        { who: 'kasha', text: 'I followed you. Debts get paid. My main force is coming too.' },
        { who: 'commander', text: 'Keep calling each other\'s names. So nobody loses themselves.' },
      ],
      epilogue: [
        { who: 'narrator', text: 'The Demonic Sorcerer scattered, and the mist of illusions lifted.' },
        { who: 'commander', text: 'The voices in the ruins... were they really my parents?' },
        { who: 'sera', text: '"The Key isn\'t turned alone." That\'s what they said.' },
        { who: 'commander', text: 'Yeah. I\'ll believe those words weren\'t an illusion.' },
        { who: 'kasha', text: 'The sorcerer talked. Ordin headed for the top of the Demon Realm.' },
        { who: 'kasha', text: 'Where heaven\'s light leaks in. He plans to summon a god there.' },
        { who: 'bark', text: 'A god... now we\'re fighting gods too?' },
        { who: 'commander', text: 'God or not, if it uses people as fuel, we stop it.' },
      ] },

    8: { title: 'Divine Judgment',
      prologue: [
        { who: 'narrator', text: 'At the peak of the Demon Realm\'s sky, a white rift tore open.' },
        { who: 'narrator', text: 'The light pouring from it spared neither demon nor human.' },
        { who: 'sera', text: 'This is... the light I\'ve prayed to my whole life.' },
        { who: 'sera', text: 'So why is it so cold?' },
        { who: 'ordin', text: 'Behold. The god shall burn away all that is defiled.' },
        { who: 'ordin', text: 'The Demon Realm, the lands it has touched, and the people within them.' },
        { who: 'commander', text: 'Our home is in those lands!' },
        { who: 'ordin', text: 'To save the world, some must be lost. Such is the reckoning.' },
        { who: 'commander', text: 'Who gets lost isn\'t yours to decide.' },
      ],
      epilogue: [
        { who: 'narrator', text: 'The white rift closed, and the Demon Realm\'s sky turned red again.' },
        { who: 'ordin', text: 'The god... had already fallen once to the Demon Lord.' },
        { who: 'ordin', text: 'For fifteen years, it seems, I prayed to a defeated god.' },
        { who: 'bark', text: 'Boss, what do we do with the geezer? Leave him here?' },
        { who: 'commander', text: 'He comes with us. Dying to pay it off is too easy.' },
        { who: 'sera', text: '{commander}... you\'ve changed a lot. For the better.' },
        { who: 'narrator', text: 'Then, deep in the Demon Realm, great war drums boomed.' },
        { who: 'kasha', text: 'The Demon Lord\'s army is moving. Target... our world!' },
        { who: 'commander', text: 'We go back. If we don\'t stop them now, there\'s no home to return to.' },
      ] },

    9: { title: 'Absolute Crisis',
      prologue: [
        { who: 'narrator', text: 'The Demon Lord\'s host poured out of every rift in the world.' },
        { who: 'narrator', text: 'Kingdom, Empire, north and marsh: all one battlefield now.' },
        { who: 'narrator', text: 'Scattered survivors gathered under a single banner.' },
        { who: 'kasha', text: 'They all want you as supreme commander. Funny, huh? The country commander.' },
        { who: 'commander', text: 'I\'m still a village militia commander.' },
        { who: 'commander', text: 'The village I protect just got a little bigger.' },
        { who: 'bark', text: 'Ha ha ha! Let\'s stitch that on the banner.' },
        { who: 'sera', text: 'This time, let\'s all make it out alive. Promise me.' },
        { who: 'commander', text: 'I promise. And this time, I\'ll keep it to the end.' },
      ],
      epilogue: [
        { who: 'narrator', text: 'The Warrior of War fell, and the demon army\'s advance halted.' },
        { who: 'narrator', text: 'The world held on. Barely. Just barely.' },
        { who: 'ordin', text: 'I know the road to the Demon Lord\'s throne. I shall guide you.' },
        { who: 'kasha', text: 'Can we trust him? This geezer caused all of this.' },
        { who: 'commander', text: 'It\'s not trust. It\'s a chance.' },
        { who: 'ordin', text: '...Your parents spoke those very words.' },
        { who: 'bark', text: 'So it\'s over tomorrow? For real?' },
        { who: 'commander', text: 'We\'re going to end it. Together.' },
        { who: 'narrator', text: 'On the eve of battle, the campfires burned all night.' },
      ] },

    10: { title: 'Realm of Impossibility',
      prologue: [
        { who: 'narrator', text: 'The deepest part of the Demon Realm. Where no light or sound reaches.' },
        { who: 'narrator', text: 'There stood the throne of the Demon Lord.' },
        { who: 'ordin', text: 'Before the throne, the Lord\'s five vassals bar the way.' },
        { who: 'kasha', text: 'Five, huh. We just take them down one at a time.' },
        { who: 'sera', text: '{commander}, give me your hand. ...Your scar is glowing.' },
        { who: 'commander', text: 'The Key my parents left. This time, we turn it together.' },
        { who: 'bark', text: 'My hand on the boss\'s. Come on, everyone, pile on!' },
        { who: 'commander', text: 'Final operation. Solbit Clan, move out!' },
      ],
      epilogue: [
        { who: 'narrator', text: 'The Key turned, and every rift in the sky closed at once.' },
        { who: 'narrator', text: 'The Demon Realm sank back into deep sleep. This time, forever.' },
        { who: 'narrator', text: 'And a few months later: spring in Solbit Village.' },
        { who: 'bark', text: 'Boss! We\'re short on plowhands. Heroes gotta work too!' },
        { who: 'kasha', text: 'The Black Feather\'s disbanded. I\'m just Kasha now. Be nice.' },
        { who: 'sera', text: 'I left flowers on Uncle Bram\'s grave. Want to come?' },
        { who: 'commander', text: 'Yeah. Lots to tell him. I need to say it\'s all over.' },
        { who: 'commander', text: 'Bram, I only kept half my promise. But everyone\'s here.' },
        { who: 'narrator', text: 'A breeze blew over the hill. It sounded like someone laughing.' },
        { who: 'commander', text: 'We were ordinary. But together, we made it.' },
        { who: 'narrator', text: '— DEADLINE 15, The End —' },
      ] },
  },

  stages: {
    // ═══ Episode 1: The Hero's Beginning ═══
    1: {
      pre: [
        { who: 'narrator', text: 'The east palisade of Solbit Village. Torches flickered across the fields.' },
        { who: 'bram', text: 'Bandit grunts. Hold the palisade and the village is safe.' },
        { who: 'commander', text: 'First order: hold the palisade. I\'ll read the field from the rear.' },
        { who: 'sera', text: 'If you get hurt, fall back right away. I\'m here.' },
      ],
      post: [
        { who: 'bram', text: 'Not bad. Nobody went down.' },
        { who: 'commander', text: 'The tip of my baton is still shaking.' },
        { who: 'bram', text: 'A shaking hand can still give orders. That\'s enough.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'If the palisade falls, it\'s over. Hold your ground!' } ],
        last: [ { who: 'sera', text: 'One left! Just a little more!' } ],
      },
    },
    2: {
      pre: [
        { who: 'narrator', text: 'Dawn of the next day. The bandits swarmed back.' },
        { who: 'bram', text: 'Axe-wielders in the mix this time. Warriors.' },
        { who: 'bram', text: 'Warriors get angrier the more they\'re hit. Don\'t drag it out.' },
        { who: 'commander', text: 'Two on one. Take them down one at a time, for sure.' },
      ],
      post: [
        { who: 'sera', text: '{commander}, that order just now? Real commander stuff.' },
        { who: 'commander', text: 'I was just repeating what Bram always says.' },
        { who: 'bram', text: 'Repeat it enough and it becomes yours.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Target the axes first. Pincer them!' } ],
        wave: [ { who: 'bram', text: 'Second group. Don\'t rush. The palisade will hold.' } ],
        danger: [ { who: 'sera', text: '{ally}, you\'re badly hurt! Fall back, I\'ll heal you!' } ],
      },
    },
    3: {
      pre: [
        { who: 'narrator', text: 'A rocky canyon leading to the village. The bandits\' shortcut.' },
        { who: 'bram', text: 'Take the ridge above the canyon. Strikes from high ground hurt more.' },
        { who: 'commander', text: 'Wish we had more people to shoot from up high.' },
        { who: 'bram', text: 'Don\'t pine for what you lack. Win with what you have.' },
      ],
      post: [
        { who: 'narrator', text: 'A bandit supply note was found on the canyon floor.' },
        { who: 'commander', text: '"Gather at the forest lumberyard." That\'s next, then.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'The pass is narrow. They can\'t all come at once. We hold here.' } ],
        wave: [ { who: 'sera', text: 'More from the back of the canyon! Even more this time!' } ],
        last: [ { who: 'commander', text: 'Last one. Don\'t let it escape.' } ],
      },
    },
    4: {
      pre: [
        { who: 'bram', text: 'The canyon\'s far entrance. They\'re serious today.' },
        { who: 'sera', text: 'Someone\'s hiding in the shadows over there.' },
        { who: 'bram', text: 'An assassin. That one slips behind shields. Careful.' },
        { who: 'commander', text: 'Sera, stay by me. Don\'t get separated.' },
      ],
      post: [
        { who: 'commander', text: 'That assassin had a strange crystal shard on him.' },
        { who: 'sera', text: 'It\'s violet. My hand tingles when I touch it.' },
        { who: 'commander', text: '(My scar... is reacting?)' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Block the entrance. Find the one who snuck in first.' } ],
        wave: [ { who: 'bram', text: 'The shadows moved. Watch the rear!' } ],
        danger: [ { who: 'bram', text: '{ally}\'s side is collapsing. Wounded, behind the shields!' } ],
      },
    },
    5: {
      pre: [
        { who: 'narrator', text: 'The forest lumberyard, where the village\'s winter firewood is stacked.' },
        { who: 'bram', text: 'If this burns, the village won\'t survive winter. We protect it.' },
        { who: 'commander', text: 'Hide between the trees and you take fewer arrows. Use the forest.' },
        { who: 'sera', text: 'That big guy over there... he fights with just his fists.' },
      ],
      post: [
        { who: 'bark', text: 'I lose, I lose. If you\'re gonna kill me, make it quick.' },
        { who: 'commander', text: 'Why were you missing on purpose? I saw everything.' },
        { who: 'bark', text: '...Name\'s Bark. Went bandit \'cause I was starving. I hate killing.' },
        { who: 'commander', text: 'Then be our guide. To the bandit outpost.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Backs to the woodpiles. Not one step back.' } ],
        wave: [ { who: 'bram', text: 'Reinforcements from deep in the forest. Tighten ranks.' } ],
        last: [ { who: 'sera', text: 'One left! That big guy hasn\'t attacked this whole time...' } ],
      },
    },
    6: {
      pre: [
        { who: 'bark', text: 'Heh, this boss has guts. Fine, I\'ll tag along.' },
        { who: 'bark', text: 'Past this forest is the bandit outpost. I know a shortcut.' },
        { who: 'bram', text: 'Our first time on the attack.' },
        { who: 'bram', text: 'It\'s not like defending. You need the nerve to push forward.' },
        { who: 'commander', text: 'We flank them. Bark takes the front.' },
        { who: 'bark', text: 'Roughest spot right off the bat. I like it!' },
      ],
      post: [
        { who: 'bark', text: 'Well? Pretty useful, ain\'t I?' },
        { who: 'sera', text: 'Not hurt? ...You really are on our side now.' },
        { who: 'commander', text: 'As of today, Bark is one of our clan.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Advance! This time we go to them.' } ],
        last: [ { who: 'bark', text: 'Take that one and the outpost is ours!' } ],
      },
    },
    7: {
      pre: [
        { who: 'narrator', text: 'Beyond the forest stretched endless sand dunes.' },
        { who: 'bark', text: 'The bandit supply route. All their water and food comes this way.' },
        { who: 'bram', text: 'There\'s no cover in the sand. Watch for archers.' },
        { who: 'commander', text: 'Cut their supplies and the bandits starve. Let\'s go.' },
      ],
      post: [
        { who: 'sera', text: 'The supply crates are stamped with imperial lettering.' },
        { who: 'bram', text: 'Bandits using imperial weapons? Where\'d they get them?' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Don\'t linger in archer range!' } ],
        wave: [ { who: 'bark', text: 'Ambush behind the dunes! Knew it!' } ],
        danger: [ { who: 'sera', text: '{ally}, you\'re bleeding too much! Healing you now!' } ],
      },
    },
    8: {
      pre: [
        { who: 'narrator', text: 'An oasis in the heart of the desert. The bandits\' storehouse.' },
        { who: 'bark', text: 'The chief got his weapons here. From a hooded mage.' },
        { who: 'commander', text: 'A mage? Trading with bandits?' },
        { who: 'bram', text: 'Raid the storehouse and we\'ll find out.' },
      ],
      post: [
        { who: 'commander', text: 'This ledger... gold coins for every violet crystal brought in.' },
        { who: 'bram', text: 'Moving bandits with mere crystals. Someone\'s behind this.' },
        { who: 'bark', text: 'The chief\'s up at Red Rock Pass. Volcano country.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Sweep the storehouse guards first. We protect the supplies.' } ],
        last: [ { who: 'bark', text: 'Last one! He\'ll have the storehouse key!' } ],
      },
    },
    9: {
      pre: [
        { who: 'narrator', text: 'Red Rock Pass. Lava flowed through cracks in the ground.' },
        { who: 'bram', text: 'Stay by the lava too long and you\'ll get burned.' },
        { who: 'sera', text: 'When you end your turn, end it one tile away from the lava.' },
        { who: 'commander', text: 'The chief\'s lair is right there. We can\'t wear out here.' },
      ],
      post: [
        { who: 'bark', text: 'Up there\'s the chief\'s fortress. Let\'s finish it tonight.' },
        { who: 'commander', text: 'Everyone rest. We strike at dawn.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Careful not to get pushed toward the lava!' } ],
        wave: [ { who: 'bram', text: 'Reinforcements from the fortress. Hold the pass!' } ],
        danger: [ { who: 'bram', text: 'Fall back, {ally}! Overreach and you protect nothing!' } ],
        last: [ { who: 'sera', text: 'Just one now! Stay focused!' } ],
      },
    },
    10: {
      pre: [
        { who: 'narrator', text: 'The bandit fortress at the volcano\'s foot. Banners whipped in the hot wind.' },
        { who: 'boss', text: 'A brat with a stick is the leader? That\'s a laugh.' },
        { who: 'commander', text: 'Your days of tormenting the village end today.' },
        { who: 'boss', text: 'Bark, you traitor! I\'ll toss you in the lava first!' },
        { who: 'bark', text: 'Chief, I answer to a different boss now.' },
        { who: 'bram', text: 'Clear the grunts around the chief first. Don\'t rush.' },
      ],
      post: [
        { who: 'boss', text: 'Ugh... He promised... the fire would open...' },
        { who: 'commander', text: 'Who\'s "he"? What do you mean, the fire would open?' },
        { who: 'narrator', text: 'The chief breathed his last without an answer.' },
        { who: 'bram', text: 'It\'s not over. This may only be the beginning.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Take down the chief and the bandits scatter!' } ],
        boss: [ { who: 'boss', text: 'Pathetic militia! Taste my axe!' } ],
        wave: [ { who: 'bark', text: 'The elite from inside! The chief\'s guard!' } ],
        danger: [ { who: 'sera', text: 'The chief\'s after {ally}! Open some distance!' } ],
        last: [ { who: 'bark', text: 'Just one left! The bandits are finished today!' } ],
      },
    },
    // ═══ Episode 2: The Frozen Conspiracy ═══
    11: {
      pre: [
        { who: 'narrator', text: 'Whitespring, a village at the foot of the mountains. Even the well had frozen.' },
        { who: 'sera', text: 'Those soldiers walking toward the village... that\'s kingdom armor.' },
        { who: 'bram', text: 'Empty eyes. Not living men. Corpses bound in ice.' },
        { who: 'commander', text: 'Inside the village walls! Hold the gate!' },
      ],
      post: [
        { who: 'bark', text: 'Cut \'em down and they don\'t even bleed. Creepy.' },
        { who: 'bram', text: 'That crest... the northern garrison, disbanded fifteen years ago.' },
        { who: 'commander', text: 'Why is a dead garrison walking around now?' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Cut down anything that reaches the walls!' } ],
        wave: [ { who: 'sera', text: 'More coming out of the blizzard! It never ends!' } ],
        last: [ { who: 'bark', text: 'One left! Let\'s smash it like ice!' } ],
      },
    },
    12: {
      pre: [
        { who: 'narrator', text: 'The people of Whitespring began evacuating down the mountain.' },
        { who: 'sera', text: 'Some of those undead are wearing priest robes.' },
        { who: 'sera', text: 'Those priests are raising the other corpses back up.' },
        { who: 'commander', text: 'Target the priests. That\'s how this fight ends.' },
        { who: 'bram', text: 'Hold until every evacuee is through the gate.' },
      ],
      post: [
        { who: 'sera', text: 'Dead priests fighting in the name of the gods... I hate it.' },
        { who: 'commander', text: 'Someone made them like that. I\'ll find whoever it was.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Hold the walls until every evacuee is out!' } ],
        wave: [ { who: 'bram', text: 'Knights in the lead. Don\'t lose the priests behind the shields.' } ],
        danger: [ { who: 'sera', text: '{ally}, your hands are frozen! Hang on a moment!' } ],
      },
    },
    13: {
      pre: [
        { who: 'narrator', text: 'Frostgate Fortress, gateway to the north. Its gates were sheathed in ice.' },
        { who: 'kasha', text: 'Oh my, the country militia made it all the way here?' },
        { who: 'kasha', text: 'Kasha, of the Black Feather mercenaries. This fortress is ours.' },
        { who: 'commander', text: 'I don\'t care whose it is. Together, we finish faster.' },
        { who: 'kasha', text: 'Together? Let\'s bet on who reaches the lord\'s chamber first.' },
        { who: 'bark', text: 'Boss, I don\'t like the way she\'s smiling.' },
      ],
      post: [
        { who: 'kasha', text: 'Tch, one step late. You got lucky.' },
        { who: 'commander', text: 'Not luck. My clan members did well.' },
        { who: 'kasha', text: 'Hmph. Next time, I\'m first. Remember that.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Watch the sappers. If they get past the gate, they\'ll use bombs!' } ],
        wave: [ { who: 'kasha', text: 'Reinforcements on the walls. I\'ll send them your way.' } ],
        last: [ { who: 'bark', text: 'We\'re at the lord\'s chamber! Take that one and we win!' } ],
      },
    },
    14: {
      pre: [
        { who: 'narrator', text: 'A camp below the fortress. Deep night, the campfire flickering.' },
        { who: 'kasha', text: 'No time for sleep. Assassins are after you.' },
        { who: 'commander', text: 'Me? Why a country commander?' },
        { who: 'kasha', text: 'That\'s what the contract said. "The one with the scarred hand."' },
        { who: 'bram', text: 'Everyone up. We defend the camp.' },
      ],
      post: [
        { who: 'commander', text: 'Why warn me? We\'re rivals.' },
        { who: 'kasha', text: 'No fun if my rival dies in their sleep.' },
        { who: 'bram', text: 'Someone\'s hunting that scar. From now on, never go alone.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Gather by the fire! Don\'t scatter in the dark!' } ],
        wave: [ { who: 'kasha', text: 'A summoner called up beasts. Hit that side first!' } ],
        danger: [ { who: 'commander', text: 'The assassins go for the wounded! Stay by {ally}!' } ],
        last: [ { who: 'bark', text: 'Last assassin! Keep him alive, find out who sent him!' } ],
      },
    },
    15: {
      pre: [
        { who: 'narrator', text: 'Ancient ruins, buried in the glacier, came into view.' },
        { who: 'bram', text: 'The cold is pouring out from in there.' },
        { who: 'sera', text: 'The pattern carved on the walls... it\'s a split star.' },
        { who: 'commander', text: '(Exactly the same shape as my scar.)' },
        { who: 'commander', text: 'Mages have dug in inside. We break through.' },
      ],
      post: [
        { who: 'narrator', text: 'When {commander}\'s hand touched the ruins\' pattern, it glowed faintly.' },
        { who: 'sera', text: '{commander}, that light just now... was it reacting to you?' },
        { who: 'commander', text: 'I don\'t know. But it\'s no coincidence.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Mages can\'t take hits. Close in and finish them!' } ],
        wave: [ { who: 'bram', text: 'Shamans from deep in the ruins. Watch for curses.' } ],
        last: [ { who: 'sera', text: 'Just one more! The pattern keeps glowing!' } ],
      },
    },
    16: {
      pre: [
        { who: 'narrator', text: 'A frozen ridge. The source of the cold lay at the summit.' },
        { who: 'kasha', text: 'Race you to the top. This time, I win.' },
        { who: 'bram', text: 'Their knights move together. A covering formation.' },
        { who: 'bram', text: 'Anyone beside a knight can\'t be hit from range.' },
        { who: 'commander', text: 'Down the knights to break the formation. Then the back line.' },
      ],
      post: [
        { who: 'kasha', text: '...Lost again. You\'re better than I thought.' },
        { who: 'commander', text: 'Is that a compliment? First one I\'ve heard.' },
        { who: 'kasha', text: 'Don\'t get the wrong idea. It\'s an observation.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Break the knight formation! Without cover, it gets easy!' } ],
        wave: [ { who: 'bark', text: 'Spearmen coming down the ridge!' } ],
        danger: [ { who: 'bram', text: '{ally}, take a defensive stance and ride out one round!' } ],
      },
    },
    17: {
      pre: [
        { who: 'narrator', text: 'More ruins beyond the ridge. Screams echoed out.' },
        { who: 'bark', text: 'Ain\'t that the Black Feather? They\'re surrounded.' },
        { who: 'sera', text: 'Kasha\'s hurt! What do we do, {commander}?' },
        { who: 'commander', text: 'We save them. You can only compete while you\'re alive.' },
      ],
      post: [
        { who: 'kasha', text: '...Thanks. I won\'t say that twice.' },
        { who: 'kasha', text: 'It was a trap. The ones who hired us leaked our position.' },
        { who: 'commander', text: 'Who hired you?' },
        { who: 'kasha', text: 'An agent from the capital. Never saw a face.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Break the encirclement! Cut a path to the Black Feather!' } ],
        wave: [ { who: 'kasha', text: 'Sappers are trying to blow the pillars! Stop them!' } ],
        last: [ { who: 'kasha', text: 'The last one\'s mine to pay back. Move!' } ],
      },
    },
    18: {
      pre: [
        { who: 'narrator', text: 'A camp below the summit. The blizzard raged for a third day.' },
        { who: 'bram', text: 'I need to tell you something. The one calling the cold... I think I know him.' },
        { who: 'bram', text: 'Halvar. A royal knight who fought beside me fifteen years ago.' },
        { who: 'bram', text: 'After that night, he joined the Archmage\'s guard.' },
        { who: 'commander', text: 'The Archmage... you mean Lord Ordin?' },
        { who: 'bram', text: '...Let\'s get through tonight first. They\'re coming.' },
      ],
      post: [
        { who: 'commander', text: 'Bram, finish what you were saying earlier.' },
        { who: 'bram', text: 'An unproven suspicion is deadlier than a blade.' },
        { who: 'bram', text: 'When we meet Halvar, we\'ll hear it from his own mouth.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'The blizzard blinds us. Stick together!' } ],
        wave: [ { who: 'bram', text: 'A big one! Narrow the line to a single row!' } ],
        danger: [ { who: 'sera', text: '{ally}, you\'re freezing! Pull back!' } ],
        last: [ { who: 'bark', text: 'Last one! Clear him and we get some shut-eye!' } ],
      },
    },
    19: {
      pre: [
        { who: 'narrator', text: 'A crack in the glacier. Violet light seeped up from below.' },
        { who: 'sera', text: 'This is... just like the stories of the night the sky split.' },
        { who: 'bram', text: 'A rift from fifteen years ago. Small, but no mistake.' },
        { who: 'commander', text: 'We have to stop what\'s coming out of it. Going down.' },
      ],
      post: [
        { who: 'narrator', text: 'The rift shrank, but did not fully close.' },
        { who: 'commander', text: 'The cold flowed out of this rift and covered the mountains.' },
        { who: 'bram', text: 'Someone pried it open on purpose. The one at the summit.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Cut them down as they come out! Don\'t let them spread!' } ],
        wave: [ { who: 'sera', text: 'The rift swelled like a heartbeat! More pouring out!' } ],
        last: [ { who: 'commander', text: 'One left. Push it back and seal the rift!' } ],
      },
    },
    20: {
      pre: [
        { who: 'narrator', text: 'The summit of the Snowveil Mountains. A citadel built of ice.' },
        { who: 'bram', text: 'Halvar! It\'s me, Bram! Why are you doing this?' },
        { who: 'boss', text: 'Bram... it\'s been a while. I only follow orders.' },
        { who: 'boss', text: 'Find the Key. Those are my orders.' },
        { who: 'boss', text: 'That scar on your hand... yes. The child of the split night.' },
        { who: 'commander', text: 'You know me? What is this Key?' },
      ],
      post: [
        { who: 'boss', text: 'Bram... thank you... the ice is finally melting...' },
        { who: 'boss', text: 'The Archmage... don\'t trust that man...' },
        { who: 'narrator', text: 'Before he could finish, the knight crumbled into powder snow.' },
        { who: 'bram', text: '...Rest easy, friend.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Stop him and the mountains live. Go!' } ],
        boss: [ { who: 'boss', text: 'Freeze. Your hesitation, your memories, all of it.' } ],
        wave: [ { who: 'kasha', text: 'The Black Feather will hold the rear! Eyes forward!' } ],
        danger: [ { who: 'bram', text: '{ally}! Don\'t get caught in the cold, fall back!' } ],
        last: [ { who: 'sera', text: 'Just one now. Let\'s end this cold!' } ],
      },
    },
    // ═══ Episode 3: The Curse of the Swamp ═══
    21: {
      pre: [
        { who: 'narrator', text: 'Reedford Village in the marsh. Houses on stilts leaned crookedly.' },
        { who: 'sera', text: 'Half the villagers are sick. They can\'t move.' },
        { who: 'bark', text: 'Then we hold here. Here they come.' },
        { who: 'commander', text: 'Get stuck in the shallows and you\'re focus-fired. Stand on dry ground.' },
      ],
      post: [
        { who: 'sera', text: 'Those beasts used to be marsh deer and wolves.' },
        { who: 'commander', text: 'They\'re not sick. They\'ve been changed. By whom?' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Hold the village barricade! Don\'t get dragged to the water!' } ],
        wave: [ { who: 'bark', text: 'Something\'s crawling out of the water! Second wave!' } ],
        last: [ { who: 'sera', text: 'One left. The villagers are watching!' } ],
      },
    },
    22: {
      pre: [
        { who: 'narrator', text: 'Sera turned the village hall into an infirmary.' },
        { who: 'sera', text: 'I can\'t stop treating them. Please, protect this place.' },
        { who: 'bram', text: 'Summoners and shamans together. Curses will fly.' },
        { who: 'commander', text: 'Summons vanish if you hit the caster. Target the summoners.' },
      ],
      post: [
        { who: 'sera', text: 'Everyone lived. Today... nobody died.' },
        { who: 'commander', text: 'Sera, you haven\'t slept in three days. Rest now.' },
        { who: 'sera', text: 'I\'m scared someone will die if I rest.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Guard the infirmary walls! Sera\'s healing!' } ],
        wave: [ { who: 'bram', text: 'They brought priests too. Strike before they heal.' } ],
        danger: [ { who: 'sera', text: '{ally}! I\'m coming to you, hold on!' } ],
      },
    },
    23: {
      pre: [
        { who: 'narrator', text: 'A mangrove forest on the marsh\'s edge. Roots blocked the way.' },
        { who: 'bark', text: 'They say the plague started deep in this forest.' },
        { who: 'bram', text: 'The trees make good cover. For them and for us.' },
        { who: 'commander', text: 'Fight along the forest. Assassins leap from the shadows.' },
      ],
      post: [
        { who: 'narrator', text: 'In the heart of the forest stood a totem of black mud.' },
        { who: 'sera', text: 'The sickness is spreading from this totem. Someone put it here!' },
        { who: 'commander', text: 'It wasn\'t a natural disaster. Someone poisoned the marsh.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Check behind the trees! Assassins are hiding!' } ],
        wave: [ { who: 'bark', text: 'Sappers buried bombs between the roots!' } ],
        last: [ { who: 'commander', text: 'Last one. The way to the totem opens!' } ],
      },
    },
    24: {
      pre: [
        { who: 'narrator', text: 'There wasn\'t just one totem. They stood all over the marsh.' },
        { who: 'commander', text: 'We smash the biggest one first. This time, we attack.' },
        { who: 'bark', text: 'Those slabs of muscle are all brawlers. My kind of people.' },
        { who: 'bark', text: 'Watch out for brawlers\' counters. Don\'t go at \'em alone.' },
      ],
      post: [
        { who: 'narrator', text: 'As the totem fell, black smoke drained from the still water.' },
        { who: 'bark', text: 'Ooh, my knuckles are stinging. Feels good, though.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Push through to the totem! Don\'t get stuck in the mud!' } ],
        wave: [ { who: 'bram', text: 'Elite totem guards. Pair up against them.' } ],
        danger: [ { who: 'bark', text: '{ally}\'s hurt! I\'ll block the front, get out of there!' } ],
      },
    },
    25: {
      pre: [
        { who: 'narrator', text: 'In the middle of the marsh, a half-sunken ancient temple appeared.' },
        { who: 'bram', text: 'The heart of the curse. Even the smell is different.' },
        { who: 'sera', text: 'I hear chanting inside. They\'re performing a ritual.' },
        { who: 'commander', text: 'We cut it off before they finish. Charge!' },
      ],
      post: [
        { who: 'commander', text: 'These ritual vessels... they bear the crest of Arden\'s royal house.' },
        { who: 'bark', text: 'Royal? The same royals who sent us?' },
        { who: 'bram', text: '...Hold onto them for now. They\'ll be evidence.' },
        { who: 'sera', text: 'Uncle Bram, you know something, don\'t you?' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'The chanters first! Stop the ritual!' } ],
        wave: [ { who: 'bram', text: 'Knights from deep in the temple. Don\'t meet them head-on.' } ],
        last: [ { who: 'sera', text: 'Last one! The chant is breaking!' } ],
      },
    },
    26: {
      pre: [
        { who: 'narrator', text: 'The people of Reedford finally decided to leave the marsh.' },
        { who: 'commander', text: 'We escort the column. No stopping.' },
        { who: 'sera', text: 'No! The sick can\'t keep that pace!' },
        { who: 'commander', text: 'Stay here too long and everyone dies. I don\'t want to choose either.' },
        { who: 'bram', text: 'You\'re both right. So find a way to protect both.' },
        { who: 'commander', text: '...We set a defensive line behind the column. We match the patients\' pace.' },
      ],
      post: [
        { who: 'sera', text: 'Sorry I yelled earlier.' },
        { who: 'commander', text: 'No. If you hadn\'t spoken up, I\'d have chosen wrong.' },
        { who: 'bram', text: 'Not deciding alone. That\'s command too.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Guard the rear of the refugee column! Don\'t lose anyone!' } ],
        wave: [ { who: 'bark', text: 'More crawling out of the bog! On the column\'s flank!' } ],
        danger: [ { who: 'sera', text: 'If {ally}\'s side breaks, the column falls! Back them up!' } ],
        last: [ { who: 'bram', text: 'One left. The column is safe.' } ],
      },
    },
    27: {
      pre: [
        { who: 'narrator', text: 'Ruins across from the temple. Red-cloaked knights had made camp.' },
        { who: 'bram', text: 'Volkar imperial knights. Why are they in another nation\'s swamp?' },
        { who: 'kasha', text: 'Long time no see. I caught the Empire\'s scent and followed.' },
        { who: 'commander', text: 'Kasha? ...Come with us. No racing this time.' },
        { who: 'kasha', text: 'Hmph. Just this once.' },
      ],
      post: [
        { who: 'kasha', text: 'An imperial knight was carrying this. Next orders.' },
        { who: 'commander', text: '"When the marsh is done, to the volcano." The Empire\'s in on it too?' },
        { who: 'bram', text: 'Or the Empire is taking orders from someone, too.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Knights give cover to their neighbors. Slip in with assassins!' } ],
        wave: [ { who: 'kasha', text: 'Archers behind the ruins! They\'ve got the high ground!' } ],
        last: [ { who: 'kasha', text: 'The last one\'s mine. He\'s carrying the orders.' } ],
      },
    },
    28: {
      pre: [
        { who: 'narrator', text: 'Beneath the temple. On the drained floor, a rift gaped open.' },
        { who: 'sera', text: 'Same as the one in the north. A violet rift.' },
        { who: 'commander', text: 'My scar aches. The root of the curse is down here.' },
        { who: 'bram', text: 'Mages guard the rift. Break their ritual.' },
      ],
      post: [
        { who: 'narrator', text: 'The second rift quieted. But it did not close.' },
        { who: 'commander', text: 'In the north, and here. Someone is prying open rifts one by one.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Push toward the rift! Shatter the ritual!' } ],
        wave: [ { who: 'bark', text: 'Sappers crawling out of the rift! I smell bombs!' } ],
        danger: [ { who: 'bram', text: '{ally}! Don\'t let the rift\'s power consume you!' } ],
      },
    },
    29: {
      pre: [
        { who: 'narrator', text: 'Deep in the marsh, thick toxic fog. Nothing was visible.' },
        { who: 'sera', text: 'The fog itself is the sickness. We can\'t stay long.' },
        { who: 'bram', text: 'Beyond it lies the temple where the Lord of the Marsh awoke.' },
        { who: 'commander', text: 'We open a path. Don\'t get separated in the fog.' },
      ],
      post: [
        { who: 'narrator', text: 'The fog parted, revealing the shadow of a vast temple.' },
        { who: 'bark', text: 'Whatever\'s in there is the real king.' },
        { who: 'commander', text: 'We finish it tomorrow. Tonight, everyone warm up.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Stay together in the fog! Go for combo attacks!' } ],
        wave: [ { who: 'sera', text: 'Summons keep multiplying in the fog!' } ],
        last: [ { who: 'commander', text: 'One left. The path is opening!' } ],
      },
    },
    30: {
      pre: [
        { who: 'narrator', text: 'The temple\'s deepest chamber. Swamp water rose into a giant form.' },
        { who: 'boss', text: 'Little things. You smell of the one who summoned me.' },
        { who: 'commander', text: 'The one who summoned you? Who is it?' },
        { who: 'boss', text: 'Child of the violet hand. You too will go to that one soon.' },
        { who: 'sera', text: 'Defeat that thing and the marsh will be clean. Let\'s go!' },
      ],
      post: [
        { who: 'boss', text: 'The swamp... never dries... fire... is next...' },
        { who: 'narrator', text: 'Where the Lord melted away, an old map was found.' },
        { who: 'commander', text: 'Three places are marked. The north, the marsh, and the Empire.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Clear out the casters guarding the Lord first!' } ],
        boss: [ { who: 'boss', text: 'The swamp shall swallow you. Your breath, your names.' } ],
        wave: [ { who: 'bram', text: 'The summons never end. Go for the main body!' } ],
        danger: [ { who: 'sera', text: 'The poison\'s spreading! Come to me, {ally}!' } ],
        last: [ { who: 'bark', text: 'Last one! Let\'s finish cleaning up this swamp!' } ],
      },
    },
    // ═══ Episode 4: The Burning Empire ═══
    31: {
      pre: [
        { who: 'narrator', text: 'A stone fort on the border. The rebels\' last gate.' },
        { who: 'narrator', text: 'Beyond the horizon, the spearpoints of the imperial army glinted.' },
        { who: 'bram', text: 'They have numbers. But the walls are thick. We can hold.' },
        { who: 'commander', text: 'Cut them down as they reach the wall. Don\'t rush the attack order.' },
      ],
      post: [
        { who: 'narrator', text: 'The rebel soldiers cheered for the clan.' },
        { who: 'bark', text: 'Never thought folks here would be clapping for us.' },
        { who: 'commander', text: 'They\'re just protecting their homes too. Like us.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Backs to the wall! If this gate falls, it\'s over!' } ],
        wave: [ { who: 'bram', text: 'Imperial spearmen. Their line is long; hit the flank.' } ],
        danger: [ { who: 'sera', text: '{ally}, fall back inside the walls!' } ],
        last: [ { who: 'bark', text: 'Last one! The gate is ours!' } ],
      },
    },
    32: {
      pre: [
        { who: 'narrator', text: 'A crimson canyon leading into the imperial heartland.' },
        { who: 'kasha', text: 'Stop, {commander}. Don\'t come this way.' },
        { who: 'kasha', text: 'The Black Feather\'s main force signed with the Empire. And I\'m their leader.' },
        { who: 'commander', text: 'So we\'re enemies now?' },
        { who: 'kasha', text: '...I won\'t draw my blade myself. But the canyon is full of imperials.' },
      ],
      post: [
        { who: 'commander', text: 'Kasha never showed up.' },
        { who: 'sera', text: 'She\'s hurting too. You saw her face.' },
        { who: 'bram', text: 'A blade bound by contract cuts itself free someday.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'High ground first! Miss the first move and we\'re trapped!' } ],
        wave: [ { who: 'bark', text: 'Assassins pouring in from both sides of the canyon!' } ],
        last: [ { who: 'commander', text: 'One left. We\'re getting out of this canyon!' } ],
      },
    },
    33: {
      pre: [
        { who: 'narrator', text: 'A rebel village at the volcano\'s foot: Ashwell.' },
        { who: 'narrator', text: 'Lava channels encircling the village boiled red.' },
        { who: 'bram', text: 'Sappers coming with bombs. They\'ll go for the walls.' },
        { who: 'sera', text: 'Stand next to lava and you\'ll get burned. Pick your spots.' },
        { who: 'commander', text: 'Down the sappers first. Before the bombs go off!' },
      ],
      post: [
        { who: 'narrator', text: 'The village children handed the clan members scorched bread.' },
        { who: 'bark', text: 'Who knew burnt bread could taste this good.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Keep the sappers off the walls! Cut them off before they close!' } ],
        wave: [ { who: 'bram', text: 'Mage squad firing from the rear. Spread out!' } ],
        danger: [ { who: 'sera', text: 'Bad burns! Get away from the lava, {ally}!' } ],
        last: [ { who: 'sera', text: 'Last one! The village is safe!' } ],
      },
    },
    34: {
      pre: [
        { who: 'narrator', text: 'The rim of the volcano\'s crater. An imperial mages\' ritual ground.' },
        { who: 'bram', text: 'A ritual to wake the volcano. If it works, this land becomes a sea of fire.' },
        { who: 'commander', text: 'Cold in the north, plague in the marsh... now fire.' },
        { who: 'commander', text: 'We break the ritual. If lava blocks the path, we go around.' },
      ],
      post: [
        { who: 'narrator', text: 'The ritual broke, and the crater\'s rumbling faded.' },
        { who: 'commander', text: 'There\'s a split-star pattern on the floor here too.' },
        { who: 'bram', text: 'Meaning the same person designed all three.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'The casters are mid-ritual. No time. Charge!' } ],
        wave: [ { who: 'bark', text: 'Summons crawling up out of the crater!' } ],
        last: [ { who: 'commander', text: 'Last caster. Break the ritual for good!' } ],
      },
    },
    35: {
      pre: [
        { who: 'narrator', text: 'The obsidian citadel, Obsidian Gate. Key to the Empire\'s western defense.' },
        { who: 'narrator', text: 'The village below it burned at the imperial army\'s hands.' },
        { who: 'kasha', text: '...This wasn\'t in the contract. Burning their own people.' },
        { who: 'kasha', text: 'The Black Feather voids the contract. From now on, I\'m with you.' },
        { who: 'commander', text: 'Thanks for coming back, Kasha.' },
        { who: 'kasha', text: 'Don\'t get the wrong idea. I just won\'t have my name dragged through the mud.' },
      ],
      post: [
        { who: 'kasha', text: 'Found this in the imperial commander\'s quarters. A letter from the kingdom.' },
        { who: 'commander', text: 'The signature\'s been erased. But this handwriting...' },
        { who: 'bram', text: 'To the imperial castle. The emperor will have the original.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'We hold the citadel and open the gate! Both!' } ],
        wave: [ { who: 'kasha', text: 'The Black Feather will handle the archers on the walls!' } ],
        danger: [ { who: 'kasha', text: '{ally}\'s exposed! I\'ll cover!' } ],
        last: [ { who: 'bark', text: 'One left! Let\'s throw open the gate!' } ],
      },
    },
    36: {
      pre: [
        { who: 'narrator', text: 'A lava canal carrying supplies to the imperial castle.' },
        { who: 'bark', text: 'Supply wagons cross that bridge nonstop.' },
        { who: 'bram', text: 'On the bridge, use shoves. Push them into a blocked side and they collide.' },
        { who: 'commander', text: 'Cut the supply line and the castle wavers. Go!' },
      ],
      post: [
        { who: 'narrator', text: 'The supply bridge collapsed, cutting off the castle across the canal.' },
        { who: 'kasha', text: 'The emperor\'s a rat in a trap now.' },
        { who: 'commander', text: 'Cornered rats fight the hardest. Stay sharp.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Take the bridge! Don\'t get pushed toward the lava!' } ],
        wave: [ { who: 'bark', text: 'Knights coming down from the castle! At the end of the bridge!' } ],
        last: [ { who: 'kasha', text: 'Last one. Get ready to cut the bridge!' } ],
      },
    },
    37: {
      pre: [
        { who: 'narrator', text: 'The rebel headquarters. The emperor launched a final counterattack.' },
        { who: 'narrator', text: 'Fireballs rained down from the sky.' },
        { who: 'sera', text: 'We\'re overflowing with wounded. If HQ falls, they all die!' },
        { who: 'bram', text: 'Whoever holds out wins this fight. Defend the position.' },
        { who: 'commander', text: 'Split up: who holds in a defensive stance, and who strikes!' },
      ],
      post: [
        { who: 'narrator', text: 'The rain of fire stopped, and the emperor\'s army withdrew.' },
        { who: 'sera', text: 'We held... we actually held.' },
        { who: 'bram', text: 'Outstanding, Commander. Guess I can\'t call you kid anymore.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Front line at the barricade, hold fast! Rotate on my signal!' } ],
        wave: [ { who: 'bram', text: 'Assassins slipping through gaps in the barricade! Watch the rear!' } ],
        danger: [ { who: 'sera', text: '{ally}! You can\'t stay in the flames!' } ],
        last: [ { who: 'bark', text: 'Last one! HQ\'s safe!' } ],
      },
    },
    38: {
      pre: [
        { who: 'narrator', text: 'The outskirts of the Volkar imperial castle. Three rings of walls.' },
        { who: 'kasha', text: 'We breach the first wall; the rebels hold our backs.' },
        { who: 'bram', text: 'Spearmen and archers hold the high ground on the walls.' },
        { who: 'commander', text: 'Hit the ones outside the knights\' cover first and open a gap.' },
      ],
      post: [
        { who: 'narrator', text: 'The castle\'s outer wall fell. Heat blasted from within.' },
        { who: 'commander', text: 'Beneath the palace, I feel a power so strong my scar hurts.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Aim for the top of the walls! Take the high ground!' } ],
        wave: [ { who: 'kasha', text: 'Palace guard. These ones are seriously strong!' } ],
        danger: [ { who: 'bram', text: '{ally}, don\'t stand fast under the walls! Move!' } ],
      },
    },
    39: {
      pre: [
        { who: 'narrator', text: 'Beneath the palace. A massive rift pulsed red.' },
        { who: 'sera', text: 'It\'s far bigger than the north or the marsh. This is the third.' },
        { who: 'bram', text: 'When three rifts converge... some enormous gate will open.' },
        { who: 'commander', text: 'Clear out the guards first. We have to stop the rift.' },
      ],
      post: [
        { who: 'narrator', text: 'On the altar before the rift lay a single sealed letter.' },
        { who: 'commander', text: '"Feed the flames as promised. When the gate opens, you shall be rewarded."' },
        { who: 'commander', text: 'The seal is... Ordin\'s. The Royal Archmage.' },
        { who: 'sera', text: 'Then who have we been fighting for all this time?' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Target the casters guarding the rift! Charge!' } ],
        wave: [ { who: 'bark', text: 'The rift\'s growing, and now sappers are popping out!' } ],
        danger: [ { who: 'sera', text: 'The rift\'s power is surging, {ally}! Get clear!' } ],
        last: [ { who: 'commander', text: 'One left. On to the altar!' } ],
      },
    },
    40: {
      pre: [
        { who: 'narrator', text: 'The palace throne room. Everything blazed with lava light.' },
        { who: 'boss', text: 'So the kingdom\'s dogs made it this far.' },
        { who: 'commander', text: 'Ordin sent you this letter, didn\'t he? What did you promise?' },
        { who: 'boss', text: 'Promise? Feed the fire, and he\'d give me a new world.' },
        { who: 'boss', text: 'None of that matters now. I\'ll burn it all!' },
      ],
      post: [
        { who: 'boss', text: 'Urgh... we were... only the backup...' },
        { who: 'boss', text: 'The real gate... is in the Abyss... what your Archmage wants is...' },
        { who: 'narrator', text: 'The emperor\'s body turned to flame and dwindled away.' },
        { who: 'commander', text: 'Backup... so the real thing hasn\'t even started yet.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'The mages around the emperor first! Cut off the fire!' } ],
        boss: [ { who: 'boss', text: 'Burn! The Empire\'s fire never dies!' } ],
        wave: [ { who: 'kasha', text: 'Guard summoners coming from behind the throne!' } ],
        danger: [ { who: 'bram', text: '{ally}! Pillar of fire incoming, dodge!' } ],
        last: [ { who: 'sera', text: 'Last one! Let\'s put out this fire!' } ],
      },
    },
    // ═══ Episode 5: The End of the Abyss ═══
    41: {
      pre: [
        { who: 'narrator', text: 'The edge of the Abyss. A forward base hastily raised by the rebels and the clan.' },
        { who: 'bram', text: 'Whatever climbs up from below, we stop it here.' },
        { who: 'bark', text: 'This palisade\'ll topple if the wind blows too hard.' },
        { who: 'commander', text: 'If the palisade is weak, we become the wall. Hold your ground!' },
      ],
      post: [
        { who: 'sera', text: 'Those monsters have empty eyes, like the undead in the north.' },
        { who: 'commander', text: 'They came from the same hand. We have to go down.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'They\'re climbing out of the Abyss! Defend the base!' } ],
        wave: [ { who: 'bram', text: 'Second wave. Knights in the lead.' } ],
        last: [ { who: 'bark', text: 'Last one! Let\'s send him back down the hole!' } ],
      },
    },
    42: {
      pre: [
        { who: 'narrator', text: 'A spiral path wound endlessly down the wall of the Abyss.' },
        { who: 'sera', text: 'The deeper we go, the less light. My prayers feel heavier.' },
        { who: 'bram', text: 'On narrow paths, shoves are deadly. Stay by the wall.' },
        { who: 'commander', text: 'Enemies at every turn. We break through one by one, going down.' },
      ],
      post: [
        { who: 'narrator', text: 'In the darkness, someone whispered {commander}\'s name.' },
        { who: 'commander', text: '...Did someone just call me?' },
        { who: 'bark', text: 'Nobody called you, boss. Why you gotta give me the creeps?' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Ride the slope and push down! Advance!' } ],
        wave: [ { who: 'bram', text: 'Archers below. Hug the wall\'s shadow.' } ],
        danger: [ { who: 'sera', text: '{ally}, that\'s the cliff edge! Careful!' } ],
      },
    },

    43: {
      pre: [
        { who: 'narrator', text: 'The ancients\' lift altar. The only way down.' },
        { who: 'bram', text: 'The altar takes time to start. Hold until it does.' },
        { who: 'commander', text: 'Ring formation around the altar. Leave no side open.' },
        { who: 'bark', text: 'A whole pack of warriors. Guess I\'m using my fists today.' },
      ],
      post: [
        { who: 'narrator', text: 'The stone altar rumbled low and began sinking into the Abyss.' },
        { who: 'sera', text: 'Did people really build this altar? It\'s so old.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Hold until the altar moves! Keep formation!' } ],
        wave: [ { who: 'bram', text: 'Gladiators. Watch the counters. Hit them in pairs!' } ],
        danger: [ { who: 'bram', text: '{ally}, take a defensive stance and catch your breath!' } ],
        last: [ { who: 'sera', text: 'One left! The altar\'s starting to move!' } ],
      },
    },
    44: {
      pre: [
        { who: 'narrator', text: 'Halfway down the Abyss, a vast ancient fortress slept in the dark.' },
        { who: 'bram', text: 'These wall markings. Same builders as the northern ruins.' },
        { who: 'commander', text: 'Drive out whoever holds it, then find the records.' },
      ],
      post: [
        { who: 'narrator', text: 'The fortress murals showed people holding a split star.' },
        { who: 'sera', text: 'These people... they\'re closing the sky\'s rift by hand.' },
        { who: 'commander', text: '"Sealers." It says the Key... passes down by blood.' },
        { who: 'bram', text: '...It\'s time. When this fight\'s over, I\'ll tell you everything.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Break the gate and go in! Take back the ancient fortress!' } ],
        wave: [ { who: 'bark', text: 'Casters pouring out from inside the keep!' } ],
        last: [ { who: 'commander', text: 'Last one. Clear the way to the murals!' } ],
      },
    },
    45: {
      pre: [
        { who: 'narrator', text: 'Past the fortress, deeper still. A knight in black armor waited.' },
        { who: 'boss', text: 'The Key has walked down on its own.' },
        { who: 'commander', text: 'Key, Key... The name\'s {commander}. Remember it.' },
        { who: 'boss', text: 'Names mean nothing before the Gate.' },
        { who: 'bram', text: 'He\'s a knight. His front is solid. Go for his back.' },
      ],
      post: [
        { who: 'boss', text: 'I am... only a lesser gatekeeper... deeper below...' },
        { who: 'narrator', text: 'Where the knight fell, the ground sank deeper still.' },
        { who: 'commander', text: 'This isn\'t the bottom. Something bigger is down there.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Strip his guards and surround the knight!' } ],
        boss: [ { who: 'boss', text: 'The Key to the Gate. The rest, to the dark.' } ],
        wave: [ { who: 'bram', text: 'Abyssal knights. Break their cover formation!' } ],
        danger: [ { who: 'sera', text: '{ally}! That knight is only after you!' } ],
        last: [ { who: 'bark', text: 'Last one! Let\'s melt this tin can!' } ],
      },
    },
    46: {
      pre: [
        { who: 'narrator', text: 'The Abyss\'s lower depths. Summoners called up monsters without end.' },
        { who: 'bram', text: 'Hit the casters, or the summons never stop.' },
        { who: 'kasha', text: 'Then I\'ll slip in behind. Shadow paths are my specialty.' },
        { who: 'commander', text: 'While Kasha hits the casters, we pin down the front.' },
      ],
      post: [
        { who: 'kasha', text: 'Twelve casters. Seven were mine. This one\'s my win.' },
        { who: 'commander', text: 'Fine. I\'ll give you this one.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Casters first! Don\'t get tied up by the summons!' } ],
        wave: [ { who: 'kasha', text: 'Casters set up another circle! In the back this time!' } ],
        last: [ { who: 'kasha', text: 'Last caster. I\'m going!' } ],
      },
    },
    47: {
      pre: [
        { who: 'narrator', text: 'A cave sealed on every side. The clan was cut off.' },
        { who: 'sera', text: 'I... can\'t pray. I\'ve got nothing left.' },
        { who: 'commander', text: 'Sera, rest in the back. We\'ll hold the front.' },
        { who: 'bram', text: 'A pack of mages is watching from above. Take cover.' },
        { who: 'commander', text: 'Stay on alert. Hit whatever comes close first.' },
      ],
      post: [
        { who: 'sera', text: 'Sorry. Everyone got hurt worse because of me.' },
        { who: 'commander', text: 'You rested, so we get a next fight. Don\'t be sorry.' },
        { who: 'bram', text: '(...Grown up so much. Just like those two.)' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Block the cave mouth! Protect Sera!' } ],
        wave: [ { who: 'bark', text: 'Summons dropping from the ceiling!' } ],
        danger: [ { who: 'commander', text: 'Pull the wounded back first! We\'ll reform the line!' } ],
        last: [ { who: 'bram', text: 'One left. Finish it calmly.' } ],
      },
    },
    48: {
      pre: [
        { who: 'narrator', text: 'A stone bridge spanning the Abyss, cracked all over.' },
        { who: 'bram', text: 'Past the bridge is the bottom of the Abyss. I can feel it.' },
        { who: 'bark', text: 'If this bridge goes, there\'s no way back either.' },
        { who: 'commander', text: 'Cross fast, then hold the far side. We need both.' },
      ],
      post: [
        { who: 'narrator', text: 'Half the bridge collapsed. Blood ran down Bram\'s leg.' },
        { who: 'sera', text: 'Bram, your leg... Let me heal it now!' },
        { who: 'bram', text: 'I\'m fine. Old bodies creak. That\'s all.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Advance onto the bridge! Don\'t linger on the cracks!' } ],
        wave: [ { who: 'kasha', text: 'Knights are blocking the bridge on the far side!' } ],
        danger: [ { who: 'bram', text: '{ally}, get pushed off the edge and it\'s over!' } ],
        last: [ { who: 'bark', text: 'One left! Let\'s get across!' } ],
      },
    },
    49: {
      pre: [
        { who: 'bram', text: 'As promised, I\'ll tell you. What happened that night, 15 years ago.' },
        { who: 'bram', text: 'Your parents were royal Sealers. They closed the rifts in the sky.' },
        { who: 'bram', text: 'Ordin tried to open the rift. They closed it with their lives.' },
        { who: 'bram', text: 'That day, I made them a promise. That I\'d protect their child.' },
        { who: 'commander', text: '...Is that why you were in the village? For 15 years?' },
        { who: 'bram', text: 'Yes. And today\'s the day I keep that promise.' },
      ],
      post: [
        { who: 'bram', text: 'Commander. I\'ll hold that passage. You all go to the bottom.' },
        { who: 'commander', text: 'No! Come with us! Your leg is hurt!' },
        { who: 'bram', text: 'With this leg, I\'m a burden. A commander knows that.' },
        { who: 'bram', text: 'You can\'t save everyone, but you abandon no one. Go.' },
      ],
      battle: {
        start: [ { who: 'bram', text: 'We only need to hold this passage. I\'ll take the front!' } ],
        wave: [ { who: 'commander', text: 'They never end... Bram, hold on a little longer!' } ],
        danger: [ { who: 'bram', text: 'Wounded, fall back! I\'ll hold this passage!' } ],
        last: [ { who: 'bram', text: 'One left. It\'s time to go, Commander.' } ],
      },
    },
    50: {
      pre: [
        { who: 'narrator', text: 'The bottom of the Abyss. The clash of swords from the passage behind fell silent.' },
        { who: 'sera', text: '{commander}... I can\'t hear Uncle Bram anymore.' },
        { who: 'commander', text: '...Eyes forward. Bram opened this road for us.' },
        { who: 'boss', text: 'The old knight was magnificent. Now it is your turn, Key.' },
        { who: 'commander', text: 'Don\'t you dare say Bram\'s name!' },
      ],
      post: [
        { who: 'boss', text: 'The Abyss... was only preparation... the road to the Demon Realm... opens...' },
        { who: 'narrator', text: 'At the end of the passage back, only a broken sword remained.' },
        { who: 'commander', text: 'Bram... You kept your promise. To the very end.' },
        { who: 'commander', text: 'Now it\'s my turn to protect. Everyone who\'s left.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'All units, attack! Don\'t let the road Bram held go to waste!' } ],
        boss: [ { who: 'boss', text: 'Command clouded by rage is nothing but openings. Come!' } ],
        wave: [ { who: 'kasha', text: 'Elites waking up from the floor! Stay sharp!' } ],
        danger: [ { who: 'sera', text: '{ally}, don\'t push forward! Hold on until I get there!' } ],
        last: [ { who: 'bark', text: 'One left, boss! This one\'s for the old man!' } ],
      },
    },
    // ═══ Episode 6: Hell's Gate ═══
    51: {
      pre: [
        { who: 'narrator', text: 'The fields south of the royal capital. Refugees crowded beneath the rift in the sky.' },
        { who: 'sera', text: 'They say the road to the capital is cut off. Everyone\'s stuck here.' },
        { who: 'commander', text: 'We set up a refugee camp. Stop everything coming down from the rift.' },
        { who: 'bark', text: 'Our first defense without the old man. Let\'s do this.' },
      ],
      post: [
        { who: 'narrator', text: 'An old man took {commander}\'s hand and bowed his head.' },
        { who: 'commander', text: '(Bram must have held on, looking at faces like these.)' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Hold the camp! Not one of them reaches the refugees!' } ],
        wave: [ { who: 'kasha', text: 'Second wave from the rift! Bigger this time!' } ],
        last: [ { who: 'sera', text: 'One left! Just a little more, everyone!' } ],
      },
    },
    52: {
      pre: [
        { who: 'narrator', text: 'Day two. Among the enemies from the rift were familiar faces.' },
        { who: 'bark', text: 'That\'s... my little brothers from the bandit days. Eyes all red.' },
        { who: 'sera', text: 'Ice soldiers from the north too. They were all dragged into the Demon Realm.' },
        { who: 'bark', text: 'Boss, those lads... I\'ll put them to rest myself.' },
        { who: 'commander', text: 'Don\'t carry it alone, Bark. We go together.' },
      ],
      post: [
        { who: 'bark', text: '...Sorry, lads. Don\'t go hungry anymore.' },
        { who: 'commander', text: 'Bark, you okay?' },
        { who: 'bark', text: 'Hardly. Still, glad you\'re beside me, boss.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Old enemies or not, they\'re Demon Realm puppets now. Hold!' } ],
        wave: [ { who: 'kasha', text: 'Knights circling around the camp\'s flank!' } ],
        danger: [ { who: 'bark', text: '{ally}, get behind me, now!' } ],
      },
    },
    53: {
      pre: [
        { who: 'narrator', text: 'Right under the rift, a stronghold where monsters had nested.' },
        { who: 'kasha', text: 'That nest is holding the rift open. Smash it and the gap shrinks.' },
        { who: 'commander', text: 'This time we attack. Smash the nest!' },
      ],
      post: [
        { who: 'narrator', text: 'As the nest fell, one of the rifts in the sky faded.' },
        { who: 'sera', text: 'We can close them. One at a time, we can close them!' },
        { who: 'commander', text: 'But that gate up north... it\'s nothing like this size.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Cut a path to the nest! Break the flanks first!' } ],
        wave: [ { who: 'bark', text: 'More monsters pouring out of the nest!' } ],
        last: [ { who: 'kasha', text: 'One left. To the heart of the nest!' } ],
      },
    },
    54: {
      pre: [
        { who: 'narrator', text: 'The volcanic lands of the Volkar Empire. A rift had opened here too.' },
        { who: 'narrator', text: 'The rebels were now the Empire\'s provisional government.' },
        { who: 'kasha', text: 'The Empire\'s people want our help. They want to repay what they owe you.' },
        { who: 'commander', text: 'Let\'s fight together. We\'ve been through lava fields before.' },
      ],
      post: [
        { who: 'narrator', text: 'Imperial soldiers lined up beneath the clan\'s banner.' },
        { who: 'bark', text: 'Shoulder to shoulder with imperial troops. Live long enough, you see everything.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Don\'t end your turn next to lava! Watch for burns!' } ],
        wave: [ { who: 'kasha', text: 'More coming down from the rift! The imperials have the left!' } ],
        danger: [ { who: 'sera', text: '{ally}, that burn is deep! Fall back!' } ],
        last: [ { who: 'bark', text: 'Last one! Let\'s look good in front of the imperials!' } ],
      },
    },
    55: {
      pre: [
        { who: 'narrator', text: 'The road to the royal capital. Its defenses were crumbling.' },
        { who: 'sera', text: 'This time I\'ll raise the barrier. I can pray again.' },
        { who: 'commander', text: 'Don\'t push it. If you fall, so does the barrier.' },
        { who: 'sera', text: 'I know. So protect me. Trust me.' },
      ],
      post: [
        { who: 'sera', text: 'I did it... my prayers reach again.' },
        { who: 'commander', text: 'We held because of you, Sera.' },
        { who: 'sera', text: 'Uncle Bram always said it. Nobody does it alone.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Protect Sera\'s barrier! Hit anyone who gets close!' } ],
        wave: [ { who: 'kasha', text: 'Casters are targeting the barrier! Stop them!' } ],
        danger: [ { who: 'sera', text: '{ally}, get inside the barrier!' } ],
        last: [ { who: 'bark', text: 'One left! Barrier\'s still holding!' } ],
      },
    },
    56: {
      pre: [
        { who: 'narrator', text: 'A deep rift outside the capital. Demon Realm air poured out thick.' },
        { who: 'kasha', text: 'That rift runs all the way to the capital. The capital\'s in danger.' },
        { who: 'commander', text: 'We break straight through. Follow the rift to the capital.' },
      ],
      post: [
        { who: 'narrator', text: 'At the rift\'s end, the capital walls came into view. Smoke was rising.' },
        { who: 'sera', text: 'The capital is burning...!' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Advance along the rift! Don\'t stop!' } ],
        wave: [ { who: 'bark', text: 'Blocked front and back! Punch through one side first!' } ],
        last: [ { who: 'commander', text: 'One left. On to the capital!' } ],
      },
    },
    57: {
      pre: [
        { who: 'narrator', text: 'The capital of Arden. Half its walls had fallen to the demon army.' },
        { who: 'narrator', text: 'The royal guard had already retreated to the palace.' },
        { who: 'commander', text: 'Retake the walls and open a way out for the people.' },
        { who: 'kasha', text: 'The palace lot abandoned their people and hid. Pathetic.' },
        { who: 'commander', text: 'That\'s exactly why we\'re here.' },
      ],
      post: [
        { who: 'narrator', text: 'The capital\'s people began streaming out the south gate.' },
        { who: 'sera', text: 'They say the Archmage\'s tower is empty. Where did Ordin go?' },
        { who: 'commander', text: 'We search beneath the tower. The answer will be there.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Retake the walls! Seize the high ground!' } ],
        wave: [ { who: 'kasha', text: 'Knights pushing toward the gate!' } ],
        danger: [ { who: 'bark', text: '{ally}\'s hurt! Get them down the wall stairs!' } ],
        last: [ { who: 'sera', text: 'Last one! The south gate is open!' } ],
      },
    },
    58: {
      pre: [
        { who: 'narrator', text: 'Beneath the Archmage\'s tower. The stairs led down into a rift.' },
        { who: 'kasha', text: 'He was growing a rift under his own tower.' },
        { who: 'commander', text: 'There are guards. Break through to the study.' },
      ],
      post: [
        { who: 'commander', text: 'Ordin\'s journal. "Open the Gate and summon the god."' },
        { who: 'commander', text: '"Only a god can purify the Demon Realm. The Key to the Gate is that child."' },
        { who: 'sera', text: 'He did all this to the world just to summon a god?' },
        { who: 'kasha', text: 'That\'s not faith. That\'s madness.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Clear the guardians at the study door! Move in!' } ],
        wave: [ { who: 'bark', text: 'Summons bursting out of the walls!' } ],
        last: [ { who: 'kasha', text: 'One left. We\'re at the study door.' } ],
      },
    },
    59: {
      pre: [
        { who: 'narrator', text: 'The Ashen Plains north of the capital. The Hell Gate towered into the sky.' },
        { who: 'narrator', text: 'Before it stood the allied army\'s last camp.' },
        { who: 'commander', text: 'Before we hit the gate\'s warden, we hold the camp.' },
        { who: 'bark', text: 'The ones pouring out of that gate... no joke how many.' },
        { who: 'commander', text: 'Meet them on alert. Shoot first, strike first.' },
      ],
      post: [
        { who: 'narrator', text: 'The camp held. A huge shadow rose before the Gate.' },
        { who: 'sera', text: 'That\'s the gatekeeper. Get past it and we can close the Gate.' },
        { who: 'commander', text: '(Can we really? My scar feels strangely restless.)' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Hold the camp! This is the last line of defense!' } ],
        wave: [ { who: 'kasha', text: 'Reinforcements from the Gate! There\'s no end to them!' } ],
        danger: [ { who: 'commander', text: 'Cover {ally}\'s spot! We don\'t give up this camp!' } ],
        last: [ { who: 'bark', text: 'One left! The camp is ours!' } ],
      },
    },
    60: {
      pre: [
        { who: 'narrator', text: 'Right before the Hell Gate. A giant knight stood with its back to the Gate.' },
        { who: 'boss', text: 'Only the Key\'s blood may pass this Gate.' },
        { who: 'commander', text: 'Not here to pass. I\'m here to close it.' },
        { who: 'boss', text: 'Close it or open it, it shall be decided the moment you defeat me.' },
        { who: 'kasha', text: 'Something\'s off. That smells like a trap.' },
      ],
      post: [
        { who: 'boss', text: 'Good... the Key\'s blood... has touched the Gate...' },
        { who: 'narrator', text: 'With the warden fallen, blood seeped from {commander}\'s scar.' },
        { who: 'narrator', text: 'From fingertips raised before the Gate, a drop of blood touched it.' },
        { who: 'commander', text: 'My scar is burning... The Gate... is moving?!' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Strip away the warden\'s escorts first!' } ],
        boss: [ { who: 'boss', text: 'I am the Gate. To pass the Gate, pass me.' } ],
        wave: [ { who: 'kasha', text: 'Reinforcements from inside the Gate! We\'re boxed in!' } ],
        danger: [ { who: 'sera', text: '{ally}! You\'re bleeding too much!' } ],
        last: [ { who: 'bark', text: 'One left! This ends it!' } ],
      },
    },
    // ═══ Episode 7: Demonic Realm ═══
    61: {
      pre: [
        { who: 'narrator', text: 'The first land past the Gate. The clan built a beachhead on black rock.' },
        { who: 'kasha', text: 'The Gate home is at our backs. Lose this and we\'re done.' },
        { who: 'commander', text: 'Hold the beachhead. Give the demons no way through.' },
        { who: 'sera', text: 'The air here... every breath makes my head ring.' },
      ],
      post: [
        { who: 'bark', text: 'We held. But the sun won\'t set. No nights here?' },
        { who: 'commander', text: 'Don\'t trust time or roads here. Just trust each other.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Hold the beachhead! Guard the road to the Gate!' } ],
        wave: [ { who: 'kasha', text: 'Demon knights from the cracks in the rock! Lots of them!' } ],
        danger: [ { who: 'sera', text: '{ally}, stay with me! Can you hear me?' } ],
        last: [ { who: 'bark', text: 'One left! Our first win in the Demon Realm!' } ],
      },
    },
    62: {
      pre: [
        { who: 'narrator', text: 'A field of endlessly swaying red grass stretched out.' },
        { who: 'sera', text: '{commander}... look, it\'s Solbit Village. That hill, that mill.' },
        { who: 'commander', text: 'No. The village was never that red. It\'s an illusion.' },
        { who: 'kasha', text: 'Real enemies are mixed into the illusion. Stay sharp.' },
        { who: 'commander', text: 'Even if it looks like home, don\'t hesitate. Advance!' },
      ],
      post: [
        { who: 'narrator', text: 'As the illusion lifted, the village vanished. Only ash remained.' },
        { who: 'commander', text: 'The Demon Realm turns what we love into weapons.' },
        { who: 'bark', text: 'Dirty tricks. Means we hit \'em harder.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Don\'t trust your eyes! Watch the enemy and strike!' } ],
        wave: [ { who: 'kasha', text: 'More behind the hill! Not illusions. They\'re real!' } ],
        last: [ { who: 'sera', text: 'Last one. Now let\'s take the real road.' } ],
      },
    },
    63: {
      pre: [
        { who: 'narrator', text: 'Trees of white bone formed a forest.' },
        { who: 'bark', text: 'The branches move like fingers. Gives me the creeps.' },
        { who: 'kasha', text: 'Still, a forest is a forest. We can hide in the shade.' },
        { who: 'commander', text: 'Fight along the woods. When they swarm, hit the flank.' },
      ],
      post: [
        { who: 'narrator', text: 'At the forest\'s edge stood an old signpost. Human writing.' },
        { who: 'commander', text: '"The Sealers\' Road." ...My parents came through here too.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Use the bone trees as cover! Don\'t get exposed!' } ],
        wave: [ { who: 'kasha', text: 'They\'re surrounding us from across the forest! Watch your backs!' } ],
        danger: [ { who: 'bark', text: '{ally}! I\'ll hold off the branches, get out!' } ],
      },
    },
    64: {
      pre: [
        { who: 'narrator', text: 'A bog of red water. Something breathed beneath the surface.' },
        { who: 'sera', text: 'Like Blackwater Marsh. But many times worse.' },
        { who: 'commander', text: 'We camp on the island in the middle. Stay out of the shallows.' },
        { who: 'kasha', text: 'Hold here, and they\'ll wear out crossing the bog.' },
      ],
      post: [
        { who: 'sera', text: 'Reminds me of the marsh. Uncle Bram was with us then.' },
        { who: 'commander', text: 'He still is. In the words we say.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Hold the island! Target the ones in the shallows!' } ],
        wave: [ { who: 'bark', text: 'More crawling up from the bottom of the bog!' } ],
        danger: [ { who: 'sera', text: '{ally}, get away from the water!' } ],
        last: [ { who: 'kasha', text: 'One left. We cross the bog!' } ],
      },
    },
    65: {
      pre: [
        { who: 'narrator', text: 'A canyon that screams whenever the wind passes through.' },
        { who: 'bark', text: 'My ears are about to split. That\'s all just wind?' },
        { who: 'kasha', text: 'Whoever takes the rocks up top wins. It\'s a high-ground fight.' },
        { who: 'commander', text: 'Ranged units up the slope. Your range gets longer.' },
      ],
      post: [
        { who: 'narrator', text: 'At the canyon\'s end, a black citadel pierced the sky.' },
        { who: 'commander', text: 'The sorcerer\'s tower is past that citadel, right?' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Take the high ground first! Strike from above!' } ],
        wave: [ { who: 'kasha', text: 'Casters set up on the opposite heights!' } ],
        last: [ { who: 'bark', text: 'One left! Canyon cleared!' } ],
      },
    },
    66: {
      pre: [
        { who: 'narrator', text: 'The Demon Realm\'s black citadel. Its walls writhed as if alive.' },
        { who: 'kasha', text: 'The Black Feather main force followed through the Gate. Everyone\'s here now.' },
        { who: 'commander', text: 'Reassuring. Hold the citadel while we break inside.' },
        { who: 'kasha', text: '...Racing you back then seems so stupid now.' },
      ],
      post: [
        { who: 'kasha', text: '{commander}. You\'re not my rival anymore. You\'re my comrade.' },
        { who: 'commander', text: 'I know. Let\'s still race now and then.' },
        { who: 'kasha', text: 'Hmph. I\'m winning next time.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Take the citadel entrance and push inside!' } ],
        wave: [ { who: 'kasha', text: 'Black Feather, left wall! Now!' } ],
        danger: [ { who: 'kasha', text: '{ally}, behind me! I\'ll cover you!' } ],
        last: [ { who: 'bark', text: 'Last one! The citadel falls!' } ],
      },
    },
    67: {
      pre: [
        { who: 'narrator', text: 'In the heart of the Demon Realm stood ruins built by human hands.' },
        { who: 'sera', text: 'The split-star mark again. These are the Sealers\' ruins.' },
        { who: 'commander', text: 'My scar is ringing. Something is waiting here.' },
        { who: 'kasha', text: 'The demons want to wreck the ruins. We have to protect them!' },
      ],
      post: [
        { who: 'narrator', text: 'The stone at the ruins\' center glowed, and two voices echoed.' },
        { who: 'narrator', text: '"Our child. The Key is not turned alone."' },
        { who: 'narrator', text: '"Turn it together with the hands beside you. Then it will close."' },
        { who: 'commander', text: '...Mom? Dad? Wait, I still have things to say...!' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Protect the ruins! Don\'t let them touch that stone!' } ],
        wave: [ { who: 'bark', text: 'They\'re coming at the ruins from all sides! Form a circle!' } ],
        danger: [ { who: 'sera', text: '{ally}! We\'ll guard the ruins. Fall back!' } ],
        last: [ { who: 'sera', text: 'One left! That stone is starting to glow!' } ],
      },
    },
    68: {
      pre: [
        { who: 'sera', text: '{commander}, those voices earlier... are you okay?' },
        { who: 'commander', text: 'Yeah. If anything, it\'s the first time I can see the way.' },
        { who: 'commander', text: 'Not alone, but together. That\'s the Key, they said.' },
        { who: 'narrator', text: 'The clan entered the abyssal corridor leading to the sorcerer\'s tower.' },
      ],
      post: [
        { who: 'bark', text: 'I see the tower past the corridor. The sorcerer must be up top.' },
        { who: 'kasha', text: 'They say Ordin stopped by there too. His scent is thick.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Break through the corridor! Move together!' } ],
        wave: [ { who: 'kasha', text: 'Both corridor walls opened! It\'s an ambush!' } ],
        last: [ { who: 'commander', text: 'One left. On to the tower!' } ],
      },
    },
    69: {
      pre: [
        { who: 'narrator', text: 'The fortress beneath the sorcerer\'s tower. The last wall guarding it.' },
        { who: 'kasha', text: 'Magic is raining down from the walls.' },
        { who: 'commander', text: 'Targeted clan members get marked. Clear out of those spots.' },
        { who: 'bark', text: 'See who they\'re aiming at, just dodge. Easy!' },
      ],
      post: [
        { who: 'narrator', text: 'The wall crumbled, and the tower door opened on its own.' },
        { who: 'sera', text: 'It\'s inviting us in. I don\'t like it.' },
        { who: 'commander', text: 'If we\'re invited, we should go. Politely, baton in hand.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Watch the target markers! Clear any marked spot!' } ],
        wave: [ { who: 'kasha', text: 'Elites coming down from the tower! The mage guard!' } ],
        danger: [ { who: 'sera', text: '{ally}, they\'re focusing magic on you! Move!' } ],
        last: [ { who: 'bark', text: 'One left! The tower door is opening!' } ],
      },
    },
    70: {
      pre: [
        { who: 'narrator', text: 'The top of the tower. A familiar silhouette stepped out of the mist.' },
        { who: 'commander', text: '...Bram?' },
        { who: 'fake_bram', text: 'Yeah, kid. Why did you leave me behind?' },
        { who: 'sera', text: 'Don\'t fall for it! Bram would never say that!' },
        { who: 'commander', text: 'I know. Bram called me Commander to the very end.' },
        { who: 'boss', text: 'Hmph, how dull. Then I\'ll face you in my true form.' },
      ],
      post: [
        { who: 'boss', text: 'I shook your heart... and still you did not break...' },
        { who: 'boss', text: 'Ordin... went to the top of the sky... to summon the god...' },
        { who: 'boss', text: 'And our Lord... is already watching you...' },
        { who: 'commander', text: 'Let it watch. I\'ll be there in person soon.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Don\'t be shaken by illusions! Go for the sorcerer!' } ],
        boss: [ { who: 'boss', text: 'I will tear you apart with your own memories, Key.' } ],
        wave: [ { who: 'kasha', text: 'Reinforcements from the lower floors! Block the stairs!' } ],
        danger: [ { who: 'sera', text: '{ally}! Listen to my voice, not the illusion!' } ],
        last: [ { who: 'bark', text: 'Last one! Let\'s bring this tower down!' } ],
      },
    },
    // ═══ Episode 8: Divine Judgment ═══
    71: {
      pre: [
        { who: 'narrator', text: 'A field struck by white light. The red grass burned white.' },
        { who: 'narrator', text: 'Armored figures walked out of the light. They had wings.' },
        { who: 'sera', text: 'Avatars of the god... Just like in the scriptures.' },
        { who: 'kasha', text: 'Then why are they walking toward our camp?' },
        { who: 'commander', text: 'They\'re drawing swords. Hold the camp! They\'re enemies too!' },
      ],
      post: [
        { who: 'sera', text: 'The god\'s avatars attacked us. Why...?' },
        { who: 'commander', text: 'They must see anything touched by the Demon Realm as unclean. Us included.' },
        { who: 'sera', text: 'Then what were all my years of prayer for?' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Hold the camp! Light or dark, we stop it!' } ],
        wave: [ { who: 'kasha', text: 'More descending from the sky! Knights this time!' } ],
        danger: [ { who: 'bark', text: '{ally}! That light burns on contact!' } ],
        last: [ { who: 'sera', text: '...One left. Let\'s end this.' } ],
      },
    },
    72: {
      pre: [
        { who: 'narrator', text: 'A rift in the Abyss where light and dark collide.' },
        { who: 'kasha', text: 'Demons and avatars are fighting each other. What do we do?' },
        { who: 'commander', text: 'Neither side is ours. We cut through between them.' },
        { who: 'bark', text: 'Won\'t we get pummeled from both sides?' },
      ],
      post: [
        { who: 'narrator', text: 'Past the rift, a white crack showed at the top of the sky.' },
        { who: 'commander', text: 'That\'s where Ordin is summoning the god.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Both sides are enemies! Break through the gap!' } ],
        wave: [ { who: 'kasha', text: 'Demon reinforcements turned toward us!' } ],
        last: [ { who: 'bark', text: 'One left! Let\'s get out of this mess!' } ],
      },
    },
    73: {
      pre: [
        { who: 'narrator', text: 'A citadel of white stone. Far too clean to stand in the Demon Realm.' },
        { who: 'kasha', text: 'Ordin built this, they say. A sanctum to welcome the god.' },
        { who: 'commander', text: 'Take the citadel and find the way up.' },
        { who: 'sera', text: 'This citadel... it\'s built from the skulls of worshippers...' },
      ],
      post: [
        { who: 'commander', text: 'People Ordin brought here. Sacrifices to summon the god.' },
        { who: 'sera', text: 'So it\'s fine to do this to people, as long as it\'s for a god?' },
        { who: 'commander', text: 'No. Not for any reason.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Hold the citadel gate and push inside!' } ],
        wave: [ { who: 'kasha', text: 'Light casters coming down from the upper floors!' } ],
        danger: [ { who: 'sera', text: '{ally}, you\'ve taken too much light!' } ],
        last: [ { who: 'bark', text: 'Last one! The citadel is ours!' } ],
      },
    },
    74: {
      pre: [
        { who: 'narrator', text: 'The ruins of an ancient temple. Sera knelt alone.' },
        { who: 'narrator', text: '"Priestess. Leave the Key\'s side. The Key is defiled."' },
        { who: 'sera', text: '...It\'s the god\'s voice. Telling me to leave.' },
        { who: 'commander', text: 'Sera. It\'s your choice. I won\'t blame you.' },
        { who: 'sera', text: 'Idiot. You think I don\'t know who I\'d choose?' },
        { who: 'sera', text: 'Even people the god abandons, I\'ll heal. That\'s my prayer.' },
      ],
      post: [
        { who: 'sera', text: 'The god\'s voice stopped. My heart\'s quiet instead.' },
        { who: 'commander', text: 'Thank you, Sera. Truly.' },
        { who: 'sera', text: 'I told you at the start. If you get hurt, I\'ll fix you.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Hold the ruins! Don\'t let them near Sera!' } ],
        wave: [ { who: 'kasha', text: 'The avatars are trying to take Sera! Stop them!' } ],
        danger: [ { who: 'sera', text: '{ally}! I\'ll heal you, hang on!' } ],
        last: [ { who: 'sera', text: 'Last one. I\'ll finish this with my own hands.' } ],
      },
    },
    75: {
      pre: [
        { who: 'narrator', text: 'An abyssal pillar reaching to the sky. A ladder of light hung from it.' },
        { who: 'bark', text: 'Climb that ladder and we reach the top?' },
        { who: 'kasha', text: 'Guards have set up camp at the foot of the ladder.' },
        { who: 'commander', text: 'Take the foot of the ladder. Surround them and we can pincer.' },
      ],
      post: [
        { who: 'narrator', text: 'The ladder glowed as it took the clan\'s weight.' },
        { who: 'bark', text: 'Even holds my weight. Gods make sturdy stuff.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Reform ranks! Catch your breath and finish with a pincer!' } ],
        wave: [ { who: 'kasha', text: 'Coming down from above! Block the ladder!' } ],
        last: [ { who: 'commander', text: 'One left. We climb!' } ],
      },
    },
    76: {
      pre: [
        { who: 'narrator', text: 'Midway between sky and Abyss. A battlefield of tangled light and dark.' },
        { who: 'kasha', text: 'The demon army, the avatar army, and us. A three-way fight.' },
        { who: 'commander', text: 'Let them fight each other. We just clear a path.' },
        { who: 'bark', text: 'Wait till they wear each other out? You\'ve gotten crafty, boss.' },
      ],
      post: [
        { who: 'commander', text: 'Bram would\'ve done the same. We have to save our strength.' },
        { who: 'sera', text: 'That was your call, {commander}. Not Uncle Bram\'s.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Don\'t engage either side! Open a path and hold!' } ],
        wave: [ { who: 'kasha', text: 'Both sides are coming for us at once! Tighten up!' } ],
        danger: [ { who: 'bark', text: '{ally}! Take a defensive stance and hold for one round!' } ],
        last: [ { who: 'kasha', text: 'One left! There\'s an opening, go!' } ],
      },
    },
    77: {
      pre: [
        { who: 'narrator', text: 'A fortress near the sky. The demon army chased the clan up.' },
        { who: 'kasha', text: 'We have to cut off pursuit before the top. Let\'s stop them here.' },
        { who: 'commander', text: 'Shut the fortress gate and hold. Stay on alert.' },
        { who: 'commander', text: 'Anything that enters range, we hit first.' },
      ],
      post: [
        { who: 'narrator', text: 'The pursuers collapsed. From above, Ordin\'s voice rang out.' },
        { who: 'commander', text: 'Ordin is trying to talk to us.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Hold the fortress gate! The pursuit ends here!' } ],
        wave: [ { who: 'bark', text: 'They keep crawling up from below!' } ],
        danger: [ { who: 'sera', text: '{ally}, fall back inside the gate!' } ],
        last: [ { who: 'kasha', text: 'One left. Pursuit\'s over!' } ],
      },
    },
    78: {
      pre: [
        { who: 'ordin', text: 'Young Commander. Let us strike a bargain.' },
        { who: 'ordin', text: 'Give me the Key. When the god erases the Demon Realm, the war shall end.' },
        { who: 'commander', text: 'You said it erases any land the Demon Realm has touched. Our home too.' },
        { who: 'ordin', text: 'There is no salvation without sacrifice. Your parents proved as much.' },
        { who: 'commander', text: 'My parents chose themselves. You chose others.' },
        { who: 'commander', text: 'I won\'t let a god decide who gets abandoned.' },
      ],
      post: [
        { who: 'ordin', text: 'How foolish. Then prove it before the god.' },
        { who: 'narrator', text: 'Ordin\'s apparition scattered, and the light at the top of the sky deepened.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'This fight is my answer! Clan, open the way!' } ],
        wave: [ { who: 'kasha', text: 'Ordin\'s called up more avatars!' } ],
        last: [ { who: 'commander', text: 'One left. To the top!' } ],
      },
    },
    79: {
      pre: [
        { who: 'narrator', text: 'The last stairway to the top of the sky. Ancient pillars lined the way.' },
        { who: 'sera', text: 'Sealers\' ruins. They tried to close the Gate here too.' },
        { who: 'commander', text: 'Break through the ones camped between the pillars.' },
        { who: 'bark', text: 'Get past this and we finally see that old geezer\'s mug?' },
      ],
      post: [
        { who: 'narrator', text: 'At the top of the stairs, Ordin stood before the white crack.' },
        { who: 'narrator', text: 'Half of Ordin\'s body had already turned to light.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Up the stairs! Watch behind the pillars!' } ],
        wave: [ { who: 'kasha', text: 'Archers firing from the upper pillars! They have the high ground!' } ],
        danger: [ { who: 'sera', text: '{ally}! Don\'t get pushed down the stairs!' } ],
        last: [ { who: 'bark', text: 'One left! We\'re at the top!' } ],
      },
    },
    80: {
      pre: [
        { who: 'narrator', text: 'Before the white crack. Ordin now called himself the Summoner of the God.' },
        { who: 'boss', text: 'Behold, the god approaches. The moment I have awaited fifteen years.' },
        { who: 'commander', text: 'How many did you sacrifice in those 15 years?!' },
        { who: 'boss', text: 'That was the price of saving the world.' },
        { who: 'commander', text: 'That price isn\'t yours to set.' },
        { who: 'sera', text: '{commander}, we have to break the summoning. Now!' },
      ],
      post: [
        { who: 'boss', text: 'The god... does not come... No, could it never come at all...?' },
        { who: 'narrator', text: 'The light drained from Ordin\'s body, leaving only an old mage.' },
        { who: 'bark', text: 'Boss, should I finish him?' },
        { who: 'commander', text: 'No. He has to live and see. See what he\'s done.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Clear the avatars guarding the summoning circle first!' } ],
        boss: [ { who: 'boss', text: 'In the name of the god, I judge the defiled!' } ],
        wave: [ { who: 'kasha', text: 'More avatars coming down from the crack! Hurry!' } ],
        danger: [ { who: 'sera', text: '{ally}! It\'s the light of judgment, dodge!' } ],
        last: [ { who: 'bark', text: 'One left! Let\'s end this summoning!' } ],
      },
    },
    // ═══ Episode 9: Absolute Crisis ═══
    81: {
      pre: [
        { who: 'narrator', text: 'The Ashen Plains before the capital. The allied banners stood together for the first time.' },
        { who: 'kasha', text: 'The kingdom\'s remnants, the imperials, the Black Feather. All waiting for your orders.' },
        { who: 'commander', text: 'The alliance\'s first operation. No one fights alone.' },
        { who: 'commander', text: 'We stop whatever comes out of the rift right here!' },
      ],
      post: [
        { who: 'narrator', text: 'The alliance\'s first defense ended in victory.' },
        { who: 'bark', text: 'Soldiers from different nations, slapping each other\'s shoulders.' },
        { who: 'sera', text: 'Uncle Bram would have loved to see this.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Alliance, hold the line! Seal off the rift!' } ],
        wave: [ { who: 'kasha', text: 'A huge army from the rift! Imperials, back up the right!' } ],
        danger: [ { who: 'commander', text: 'The line is thin near {ally}! Reserves, back them up!' } ],
        last: [ { who: 'bark', text: 'One left! The alliance\'s first win!' } ],
      },
    },
    82: {
      pre: [
        { who: 'narrator', text: 'North of the plains, a forward camp the demon army built before the rift.' },
        { who: 'kasha', text: 'Leave that camp and they\'ll pour out forever.' },
        { who: 'commander', text: 'We attack. Defense alone won\'t win this war.' },
      ],
      post: [
        { who: 'narrator', text: 'The demon camp burned, and one rift fell silent.' },
        { who: 'commander', text: 'The north is next. They say Frostgate is under siege.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Hit the camp! Break the flanks first!' } ],
        wave: [ { who: 'kasha', text: 'Demon knights swarming from behind the camp!' } ],
        last: [ { who: 'commander', text: 'One left. Set the camp on fire!' } ],
      },
    },
    83: {
      pre: [
        { who: 'narrator', text: 'Frostgate Fortress in the north. Where the clan first met Kasha.' },
        { who: 'kasha', text: 'I lost to you here back then. Remember?' },
        { who: 'commander', text: 'I remember. We were enemies then.' },
        { who: 'narrator', text: 'The northern survivors in the fortress cheered at the sight of the clan\'s banner.' },
        { who: 'commander', text: 'Hold the fortress and break the siege!' },
      ],
      post: [
        { who: 'narrator', text: 'The northern survivors joined the alliance.' },
        { who: 'kasha', text: 'Those are Whitespring folk. The town you protected.' },
        { who: 'commander', text: 'This time they\'ve come to protect us.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Hold the walls and break the siege! We do both!' } ],
        wave: [ { who: 'bark', text: 'More demons coming through the blizzard!' } ],
        danger: [ { who: 'kasha', text: 'They\'ve flanked to the rear! Protect {ally}\'s side!' } ],
        last: [ { who: 'sera', text: 'One left. Frostgate is safe!' } ],
      },
    },
    84: {
      pre: [
        { who: 'narrator', text: 'Reedford Village in the southern Blackwater Marsh. The demon army crossed the bog.' },
        { who: 'sera', text: 'Those are the people I healed back then! They\'ve all taken up arms.' },
        { who: 'commander', text: 'We protect the village. This time the villagers fight with us.' },
        { who: 'bark', text: 'Bog fight means watch the shallows. Know it with my eyes shut now.' },
      ],
      post: [
        { who: 'narrator', text: 'The people of Reedford gathered around Sera and bowed their heads.' },
        { who: 'sera', text: 'The people we saved back then saved us today.' },
        { who: 'commander', text: 'That\'s why we fight.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Hold the village wall! Don\'t get dragged into the bog!' } ],
        wave: [ { who: 'kasha', text: 'Second wave from across the bog!' } ],
        danger: [ { who: 'sera', text: '{ally}, I\'m coming! Just a little longer!' } ],
        last: [ { who: 'bark', text: 'One left! Hurrah for Reedford!' } ],
      },
    },
    85: {
      pre: [
        { who: 'narrator', text: 'A colossal rift in the heart of the continent. The demon army\'s main stream.' },
        { who: 'kasha', text: 'Break that and the demon army\'s supply gets cut in half.' },
        { who: 'commander', text: 'All allied forces, charge. Today we break that rift.' },
      ],
      post: [
        { who: 'narrator', text: 'The colossal rift half-closed, and the Demon Realm screamed.' },
        { who: 'ordin', text: '...Remarkable. What I could not do in fifteen years.' },
        { who: 'commander', text: 'You couldn\'t because you tried it alone.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'That\'s the signal, all charge! Sweep away the demons at the rift!' } ],
        wave: [ { who: 'kasha', text: 'Elite knights from the rift! Reform ranks!' } ],
        last: [ { who: 'commander', text: 'One left. We break the rift!' } ],
      },
    },
    86: {
      pre: [
        { who: 'narrator', text: 'The Empire\'s Obsidian Gate citadel. The provisional government\'s last stronghold.' },
        { who: 'kasha', text: 'Where the Black Feather broke its contract. Strange feeling.' },
        { who: 'commander', text: 'Hold the citadel and beat back the siege outside.' },
        { who: 'bark', text: 'Imperials take the spearmen on the walls, we take the ground.' },
      ],
      post: [
        { who: 'narrator', text: 'With Obsidian Gate held, resistance across the Empire took heart.' },
        { who: 'kasha', text: 'Breaking that contract back then was the right call.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Guard inside and outside the gate at once! Don\'t scatter!' } ],
        wave: [ { who: 'bark', text: 'Reinforcements from the volcano side! Block the gate!' } ],
        danger: [ { who: 'kasha', text: '{ally}, don\'t overdo it. I\'ll back you up!' } ],
        last: [ { who: 'sera', text: 'One left! Obsidian Gate is safe!' } ],
      },
    },
    87: {
      pre: [
        { who: 'narrator', text: 'The ancient Sealers\' ruins. The demon army swarmed in to destroy them.' },
        { who: 'ordin', text: 'Should these ruins fall, the Key\'s power shall weaken as well.' },
        { who: 'commander', text: 'Then we protect them. No matter what.' },
        { who: 'bark', text: 'Boss, this time I\'m standing at the very front.' },
      ],
      post: [
        { who: 'narrator', text: 'The ruins were saved. But Bark lay collapsed.' },
        { who: 'sera', text: 'Bark! Open your eyes! I\'m healing you right now!' },
        { who: 'bark', text: '...Boss, I ain\'t dying. Still got fields to plow.' },
        { who: 'commander', text: 'Promise me. We go home together.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Protect the ruins! Fight with your backs to the pillars!' } ],
        wave: [ { who: 'kasha', text: 'The back of the ruins is breached! Someone block it!' } ],
        danger: [ { who: 'bark', text: '{ally}\'s side is open! I\'ll hold here!' } ],
        last: [ { who: 'bark', text: 'One... left... Boss, finish it!' } ],
      },
    },
    88: {
      pre: [
        { who: 'narrator', text: 'Bark was treated at camp, and the clan set out again.' },
        { who: 'commander', text: 'We fight for Bark too. And we all go home together.' },
        { who: 'kasha', text: 'Past that rift is the Warrior of War\'s camp.' },
        { who: 'commander', text: 'We open the road. Right up to its face.' },
      ],
      post: [
        { who: 'narrator', text: 'Past the rift, the demon warlord\'s red banner came into view.' },
        { who: 'kasha', text: 'It\'s marching toward Solbit Village.' },
        { who: 'commander', text: '...We go home. We end it there.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Break through the rift! Strike for Bark too!' } ],
        wave: [ { who: 'kasha', text: 'The warlord\'s royal guard is blocking us! They\'re strong!' } ],
        last: [ { who: 'commander', text: 'One left. We\'re going home!' } ],
      },
    },
    89: {
      pre: [
        { who: 'narrator', text: 'Solbit Village. Stone walls stood where the palisade once was.' },
        { who: 'sera', text: 'The villagers built them themselves. A place for us to come home to.' },
        { who: 'bark', text: '...Ugh, someone threw sand in my eyes.' },
        { who: 'commander', text: 'The very spot where I first took command. We hold here.' },
        { who: 'commander', text: 'This time too, we won\'t lose a single person.' },
      ],
      post: [
        { who: 'narrator', text: 'The walls of Solbit did not fall.' },
        { who: 'commander', text: 'Bram, did you see? The kid made it this far.' },
        { who: 'sera', text: 'Look, red armor at the edge of the plains. It\'s the warlord.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'These are the walls of home! Not one step back!' } ],
        wave: [ { who: 'kasha', text: 'A huge army! Swarming the east wall!' } ],
        danger: [ { who: 'sera', text: '{ally}, behind the wall! Don\'t hold on while wounded!' } ],
        last: [ { who: 'bark', text: 'One left! This is our village!' } ],
      },
    },
    90: {
      pre: [
        { who: 'narrator', text: 'The plains before Solbit Village. A giant in red armor strode forward.' },
        { who: 'boss', text: 'So this tiny village is the heart of the war.' },
        { who: 'commander', text: 'Tiny or not, it doesn\'t matter. This is our home.' },
        { who: 'boss', text: 'Then I will trample it, home and all. That is war.' },
        { who: 'kasha', text: 'The whole alliance is ready. Just waiting on your signal.' },
      ],
      post: [
        { who: 'boss', text: 'This war... is lost... but our Lord... will not lose...' },
        { who: 'narrator', text: 'With the warlord fallen, the demon army crumbled back into the rift.' },
        { who: 'commander', text: 'Only one left now. The Demon Lord.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Alliance, all-out attack! The warlord\'s guard first!' } ],
        boss: [ { who: 'boss', text: 'In the name of war! Sweep them all away!' } ],
        wave: [ { who: 'kasha', text: 'Demon elite reinforcements! This should be the last wave!' } ],
        danger: [ { who: 'sera', text: '{ally}! Don\'t take a hit from the warlord!' } ],
        last: [ { who: 'bark', text: 'One left! Let\'s end this war!' } ],
      },
    },
    // ═══ Episode 10: Realm of Impossibility ═══
    91: {
      pre: [
        { who: 'narrator', text: 'The deepest layer of the Demon Realm. A giant heartbeat thudded underfoot.' },
        { who: 'ordin', text: 'To reach the throne, we shall need a beachhead here.' },
        { who: 'commander', text: 'We hold this place. It\'s our way back and our way forward.' },
        { who: 'bark', text: 'Came still in bandages. Sitting this out, I\'d regret it forever.' },
      ],
      post: [
        { who: 'narrator', text: 'Once the beachhead stood, five lights flared beyond the dark.' },
        { who: 'ordin', text: 'The Lord\'s five vassals. Each one awaits you in turn.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Hold the beachhead! The first step of the final journey!' } ],
        wave: [ { who: 'kasha', text: 'They keep coming out of the dark! Hold formation!' } ],
        danger: [ { who: 'sera', text: '{ally}! You can\'t fall here!' } ],
        last: [ { who: 'bark', text: 'One left! The road\'s opening!' } ],
      },
    },
    92: {
      pre: [
        { who: 'narrator', text: 'The first light. A knight in a tattered cloak stood leaning on a sword.' },
        { who: 'boss', text: 'I am the Lord\'s first blade. Let us duel with honor.' },
        { who: 'commander', text: '...Same stance as Bram. The old royal swordsmanship.' },
        { who: 'boss', text: 'I too was once a human knight. Very long ago.' },
        { who: 'kasha', text: 'Save the sentiment. That knight\'s cover formation is flawless.' },
      ],
      post: [
        { who: 'boss', text: 'Splendid... your teacher must have been a fine knight.' },
        { who: 'commander', text: 'The finest. Every bit as stubborn as you.' },
        { who: 'boss', text: 'Is that so... Then perhaps I, too, may rest now...' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Peel off the escort knights! Break their cover!' } ],
        boss: [ { who: 'boss', text: 'That silver baton... a royal field commander. Then command.' } ],
        wave: [ { who: 'kasha', text: 'Knight reinforcements! Guard the flanks!' } ],
        danger: [ { who: 'kasha', text: '{ally}\'s side is getting pushed! Pull out of the knights\' cover!' } ],
        last: [ { who: 'bark', text: 'One left! That\'s the first vassal done!' } ],
      },
    },
    93: {
      pre: [
        { who: 'narrator', text: 'The second light. Thousands of magic circles floated in the air.' },
        { who: 'boss', text: 'All magic is calculation. Your odds of victory are near zero.' },
        { who: 'ordin', text: 'I, too, lived by such calculations. And I was wrong.' },
        { who: 'commander', text: 'Let me show you what\'s not in your math. Hands that protect each other.' },
      ],
      post: [
        { who: 'boss', text: 'The calculation... does not add up... Why do they shield one another...?' },
        { who: 'commander', text: 'That\'s why we win.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Target the casters! Before the circles are complete!' } ],
        boss: [ { who: 'boss', text: 'Commencing removal of variables. One, two, three.' } ],
        wave: [ { who: 'kasha', text: 'Summoners pouring out of the magic circles!' } ],
        danger: [ { who: 'sera', text: '{ally}! You\'re in the middle of a circle, get out!' } ],
        last: [ { who: 'commander', text: 'One left. Let\'s end the calculation!' } ],
      },
    },
    94: {
      pre: [
        { who: 'narrator', text: 'The third light. A demon fortress rose as if to swallow the clan.' },
        { who: 'boss', text: 'I am the endless host. My summons never run dry.' },
        { who: 'kasha', text: 'We\'re trapped in the fortress. We hold, and still reach that thing.' },
        { who: 'commander', text: 'Hold the walls. Strike when the summons thin out.' },
      ],
      post: [
        { who: 'boss', text: 'The summoning... is broken... my host... has run dry...?' },
        { who: 'bark', text: 'Well, we haven\'t!' },
        { who: 'narrator', text: 'The third light went out. Two remained.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Hold the walls! If they fall, rebuild them. Take the waves head-on!' } ],
        boss: [ { who: 'boss', text: 'Kneel before the countless.' } ],
        wave: [ { who: 'bark', text: 'More pouring in! Do these summons ever end?!' } ],
        danger: [ { who: 'sera', text: 'Summons are swarming {ally}! Stop them!' } ],
        last: [ { who: 'kasha', text: 'One left! The host is broken!' } ],
      },
    },
    95: {
      pre: [
        { who: 'narrator', text: 'The fourth light. A black knight bound in chains raised its head.' },
        { who: 'boss', text: 'Human. One question. What is a human?' },
        { who: 'boss', text: 'I wished to become human. And so I was forbidden.' },
        { who: 'commander', text: '...Why did you want to be human?' },
        { who: 'boss', text: 'I do not know. I will find that answer fighting you.' },
      ],
      post: [
        { who: 'boss', text: 'Reaching out a hand to a fallen comrade... is that what a human is?' },
        { who: 'commander', text: 'Yes. At least, that\'s what we believe.' },
        { who: 'boss', text: 'Then... at the end... perhaps I was... a little like you...' },
        { who: 'sera', text: '...Rest in peace. This is my prayer.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Escorts around the chains first! Isolate the knight!' } ],
        boss: [ { who: 'boss', text: 'Show me. What you are.' } ],
        wave: [ { who: 'kasha', text: 'Reinforcements past the chains! Watch your back!' } ],
        danger: [ { who: 'bark', text: '{ally}! That knight means business, fall back!' } ],
        last: [ { who: 'sera', text: 'One left. Let\'s give it the answer.' } ],
      },
    },
    96: {
      pre: [
        { who: 'narrator', text: 'With four vassals fallen, the corridor to the throne opened.' },
        { who: 'ordin', text: 'At this corridor\'s end lies a gate guarded by the Lord\'s royal guard.' },
        { who: 'kasha', text: 'The corridor is alive. The walls are moving.' },
        { who: 'commander', text: 'Keep moving. Don\'t get caught by the walls.' },
      ],
      post: [
        { who: 'narrator', text: 'At the corridor\'s end, a huge gate gleaming black came into view.' },
        { who: 'ordin', text: 'We must make our final camp before that gate.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Hold the corridor and advance! Don\'t get cut off!' } ],
        wave: [ { who: 'bark', text: 'Enemies bursting out of the walls!' } ],
        danger: [ { who: 'sera', text: '{ally}, the corridor\'s closing in! Move!' } ],
        last: [ { who: 'kasha', text: 'One left. We\'re at the gate.' } ],
      },
    },
    97: {
      pre: [
        { who: 'narrator', text: 'Before the throne\'s gate. The clan set up its final camp.' },
        { who: 'ordin', text: 'I need time to undo the gate\'s seal. Protect me, I beg you.' },
        { who: 'kasha', text: 'Never thought I\'d see the day I guard this old man.' },
        { who: 'commander', text: 'We hold the camp. Until Ordin breaks the seal.' },
      ],
      post: [
        { who: 'ordin', text: 'The seal is nearly undone. One last layer remains.' },
        { who: 'ordin', text: 'That last layer... is mine to bear.' },
        { who: 'commander', text: 'What do you mean, Ordin?' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Hold the final camp! Protect Ordin!' } ],
        wave: [ { who: 'kasha', text: 'Royal guards charging out from past the gate!' } ],
        danger: [ { who: 'sera', text: '{ally}! Inside the camp!' } ],
        last: [ { who: 'bark', text: 'One left! The camp\'s safe!' } ],
      },
    },
    98: {
      pre: [
        { who: 'ordin', text: 'Fifteen years ago, I fled and left your parents behind.' },
        { who: 'ordin', text: 'Everything I have done since was born of that fear.' },
        { who: 'ordin', text: 'The final seal can be undone only with a mage\'s life.' },
        { who: 'commander', text: 'You said paying with your death was too easy.' },
        { who: 'ordin', text: 'Then I shall open the way while I yet live. Guard me to the end.' },
      ],
      post: [
        { who: 'narrator', text: 'As the final seal broke, Ordin\'s body scattered into light.' },
        { who: 'ordin', text: 'Tell your parents... that I am sorry...' },
        { who: 'commander', text: '...Apologize yourself. Someday, on the other side.' },
        { who: 'narrator', text: 'The gate opened. Beyond it, the captain of the royal guard waited.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Open the way while Ordin breaks the seal!' } ],
        wave: [ { who: 'kasha', text: 'The royal guard is after Ordin! Stop them!' } ],
        danger: [ { who: 'sera', text: 'The rear is breached! Everyone, to {ally}!' } ],
        last: [ { who: 'commander', text: 'One left. Ordin, just a little longer!' } ],
      },
    },
    99: {
      pre: [
        { who: 'narrator', text: 'The throne\'s antechamber. A jet-black warrior stood with a greatsword planted in the ground.' },
        { who: 'boss', text: 'You passed four vassals? Yet I am the Lord\'s shield.' },
        { who: 'boss', text: 'To reach the Lord, you must break me.' },
        { who: 'commander', text: 'Then we break you. All of us together.' },
        { who: 'bark', text: 'Bandages are off, boss. I\'m standing in front to the end.' },
      ],
      post: [
        { who: 'boss', text: 'The shield... is broken... My Lord... the Key approaches...' },
        { who: 'narrator', text: 'The final gate opened without a sound.' },
        { who: 'sera', text: '{commander}, your hand. Let\'s go in together.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Clear the royal guard and surround the warrior!' } ],
        boss: [ { who: 'boss', text: 'In the name of the Lord, halt here!' } ],
        wave: [ { who: 'kasha', text: 'The last of the royal guard! Past them, there\'s only the Lord!' } ],
        danger: [ { who: 'sera', text: '{ally}! Don\'t take a hit from that greatsword!' } ],
        last: [ { who: 'bark', text: 'One left! We\'re at the gate!' } ],
      },
    },
    100: {
      pre: [
        { who: 'narrator', text: 'The throne of the Demon Realm. Upon it sat a giant helmeted warrior.' },
        { who: 'boss', text: 'Fifteen years ago, two humans closed my Gate.' },
        { who: 'boss', text: 'And now their child walks in willingly. To offer up the Key.' },
        { who: 'commander', text: 'I\'m not here to offer it. I\'m here to lock it.' },
        { who: 'commander', text: 'Not alone, but with the hands of everyone here.' },
        { who: 'boss', text: 'However many humans gather, they break one by one in the end.' },
      ],
      post: [
        { who: 'boss', text: 'Why... break one... and another hand takes hold...?' },
        { who: 'narrator', text: 'The Commander lowered the baton and held out the scarred hand. Everyone laid theirs upon it.' },
        { who: 'commander', text: 'This is the Key. All of us.' },
        { who: 'narrator', text: 'The Key turned, and the Demon Lord\'s throne sank into the light.' },
      ],
      battle: {
        start: [ { who: 'commander', text: 'Final order! Solbit clan, all together!' } ],
        boss: [ { who: 'boss', text: 'Come, Key. I will break all that you are.' } ],
        wave: [ { who: 'kasha', text: 'The throne\'s shadows are rising! The last host!' } ],
        danger: [ { who: 'sera', text: '{ally}! Don\'t fall! We\'re here!' } ],
        last: [ { who: 'bark', text: 'One left, boss! Let\'s finish it, all together!' } ],
      },
    },
  },
};
