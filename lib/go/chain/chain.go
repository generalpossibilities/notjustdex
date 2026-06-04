// Package chain provides Acki Nacki blockchain integration.
//
// Acki Nacki is a TVM-based blockchain with GraphQL API and Solidity smart contracts.
// Key facts:
//   - GraphQL endpoint: https://mainnet.ackinacki.org/graphql
//   - Address format: workchain_id:64_hex_chars (e.g. "0:653b9a6452c7a982...")
//   - Accounts = smart contracts with balance (VMSHELL nanotokens), code, data
//   - Messages are ABI-encoded bags of cells (BOC), signed with Ed25519
//   - Three tokens: NACKL (staking), SHELL (computation credits), VMSHELL (gas)
//   - Free intra-thread transactions; DappConfig for fee subsidization
//   - Bee Engine for client-side NACKL mining
package chain

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// ─── Constants ──────────────────────────────────────────────────

const (
	DefaultEndpoint = "https://mainnet.ackinacki.org/graphql"
	TestnetEndpoint = "https://shellnet.ackinacki.org/graphql"
	WorkchainID     = 0
)

// ─── Types ──────────────────────────────────────────────────────

type Client struct {
	graphqlURL string
	httpClient *http.Client
}

type AccountInfo struct {
	Address    string `json:"address"`
	Balance    string `json:"balance"`     // VMSHELL nanotokens (string due to large numbers)
	AccType    int    `json:"acc_type"`    // 0=uninit, 1=active, 2=frozen, 3=nonExist
	LastPaid   int64  `json:"last_paid"`
	LastTransLt string `json:"last_trans_lt"`
	CodeHash   string `json:"code_hash"`
	DataHash   string `json:"data_hash"`
}

type WalletKeys struct {
	PublicKey  ed25519.PublicKey
	PrivateKey ed25519.PrivateKey
	Address    string // format: "0:64_hex_chars"
}

// ─── Constructor ────────────────────────────────────────────────

func NewClient(endpoint string) *Client {
	if endpoint == "" {
		endpoint = DefaultEndpoint
	}
	return &Client{
		graphqlURL: endpoint,
		httpClient: &http.Client{Timeout: 30 * time.Second},
	}
}

// ─── Account Queries ────────────────────────────────────────────

// GetAccount retrieves account info by address.
// Address format: "0:64_hex_chars"
func (c *Client) GetAccount(ctx context.Context, address string) (*AccountInfo, error) {
	query := fmt.Sprintf(`{
		"query": "query { blockchain { account(address: \"%s\") { info { address acc_type balance last_paid last_trans_lt code_hash data_hash } } } }"
	}`, address)

	var result struct {
		Data struct {
			Blockchain struct {
				Account *struct {
					Info AccountInfo `json:"info"`
				} `json:"account"`
			} `json:"blockchain"`
		} `json:"data"`
	}

	if err := c.graphQL(ctx, query, &result); err != nil {
		return nil, fmt.Errorf("get account: %w", err)
	}

	if result.Data.Blockchain.Account == nil {
		return nil, fmt.Errorf("account not found: %s", address)
	}

	return &result.Data.Blockchain.Account.Info, nil
}

// CheckUsernameAvailability checks if a username is available on-chain.
// Queries the DexChats identity registry contract.
func (c *Client) CheckUsernameAvailability(ctx context.Context, username string) (bool, error) {
	// In production: query the identity registry contract via getter method
	// Stub: query account existence for the derived username address
	addr := DeriveAddress([]byte(username))
	_, err := c.GetAccount(ctx, addr)
	if err != nil {
		return true, nil // account not found = available
	}
	return false, nil
}

// ResolveUsername returns the wallet address for a username.
func (c *Client) ResolveUsername(ctx context.Context, username string) (string, error) {
	// In production: call identity registry contract's getter
	// Stub: derive address from username
	return DeriveAddress([]byte(username)), nil
}

// GetBalance retrieves the VMSHELL balance for an address.
// Returns balance in nanotokens (1 VMSHELL = 10^9 nanotokens).
func (c *Client) GetBalance(ctx context.Context, address string) (uint64, error) {
	acc, err := c.GetAccount(ctx, address)
	if err != nil {
		return 0, err
	}

	// balance field is a string (nanotokens)
	var bal uint64
	if _, err := fmt.Sscanf(acc.Balance, "%d", &bal); err != nil {
		return 0, fmt.Errorf("parse balance: %w", err)
	}
	return bal, nil
}

// ─── Key Generation ─────────────────────────────────────────────

// GenerateKeys generates a new Ed25519 key pair and derives the Acki Nacki address.
func GenerateKeys() (*WalletKeys, error) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return nil, fmt.Errorf("generate key: %w", err)
	}

	addr := DeriveAddress(pub)
	return &WalletKeys{
		PublicKey:  pub,
		PrivateKey: priv,
		Address:    addr,
	}, nil
}

// DeriveAddress generates an Acki Nacki address from a public key.
// Format: "0:64_hex_chars" (workchain 0, 256-bit address = SHA-256 of pubkey)
func DeriveAddress(pubKey []byte) string {
	hash := sha256.Sum256(pubKey)
	return fmt.Sprintf("%d:%s", WorkchainID, hex.EncodeToString(hash[:]))
}

// ─── Message Signing & Submission ───────────────────────────────

// SignMessage signs a message body with the provided Ed25519 key pair.
// The message is hashed with SHA-256 before signing (simplified for PoC;
// production should use the full ABI cell bag representation hash).
func SignMessage(privateKey ed25519.PrivateKey, messageBody []byte) []byte {
	hash := sha256.Sum256(messageBody)
	return ed25519.Sign(privateKey, hash[:])
}

// VerifyMessage verifies an Ed25519 signature on a message body.
func VerifyMessage(publicKey ed25519.PublicKey, messageBody []byte, signature []byte) bool {
	hash := sha256.Sum256(messageBody)
	return ed25519.Verify(publicKey, hash[:], signature)
}

// SendMessage sends an ABI-encoded external message to the blockchain.
// messageBOC is the base64-encoded bag of cells.
func (c *Client) SendMessage(ctx context.Context, messageBOC string) (string, error) {
	// Use the GraphQL endpoint's sendMessage mutation
	mutation := fmt.Sprintf(`{
		"query": "mutation { sendMessage(message: \"%s\") { hash } }"
	}`, messageBOC)

	var result struct {
		Data struct {
			SendMessage struct {
				Hash string `json:"hash"`
			} `json:"sendMessage"`
		} `json:"data"`
	}

	if err := c.graphQL(ctx, mutation, &result); err != nil {
		return "", fmt.Errorf("send message: %w", err)
	}

	return result.Data.SendMessage.Hash, nil
}

// ─── Identity Registration ──────────────────────────────────────

// RegisterIdentity creates an on-chain identity contract.
// In production: deploys a DexChats identity contract with username + pubkey.
// Stub: builds and sends an external message to the registry contract.
func (c *Client) RegisterIdentity(
	ctx context.Context,
	keys *WalletKeys,
	username string,
) (string, error) {
	// Build ABI-encoded message body for registerIdentity function
	// In production: use proper cell serialization
	payload := fmt.Sprintf(
		`{"function":"registerIdentity","args":{"username":"%s","pubkey":"%s"}}`,
		username, hex.EncodeToString(keys.PublicKey),
	)

	sig := SignMessage(keys.PrivateKey, []byte(payload))
	messageBOC := buildMockBOC(payload, sig)

	return c.SendMessage(ctx, messageBOC)
}

// RotateSeedPhrase updates the on-chain identity root (seed rotation).
func (c *Client) RotateSeedPhrase(
	ctx context.Context,
	keys *WalletKeys,
	newIdentityRoot []byte,
) (string, error) {
	payload := fmt.Sprintf(
		`{"function":"rotateSeed","args":{"identity_root":"%s"}}`,
		hex.EncodeToString(newIdentityRoot),
	)

	sig := SignMessage(keys.PrivateKey, []byte(payload))
	messageBOC := buildMockBOC(payload, sig)

	return c.SendMessage(ctx, messageBOC)
}

// FollowUser sends a follow transaction (free intra-thread tx).
func (c *Client) FollowUser(
	ctx context.Context,
	keys *WalletKeys,
	followeeAddress string,
) (string, error) {
	payload := fmt.Sprintf(
		`{"function":"follow","args":{"followee":"%s"}}`,
		followeeAddress,
	)

	sig := SignMessage(keys.PrivateKey, []byte(payload))
	messageBOC := buildMockBOC(payload, sig)

	return c.SendMessage(ctx, messageBOC)
}

// PostContentHash records a content IPFS hash on-chain.
func (c *Client) PostContentHash(
	ctx context.Context,
	keys *WalletKeys,
	contentHash string,
) (string, error) {
	payload := fmt.Sprintf(
		`{"function":"postContent","args":{"content_hash":"%s"}}`,
		contentHash,
	)

	sig := SignMessage(keys.PrivateKey, []byte(payload))
	messageBOC := buildMockBOC(payload, sig)

	return c.SendMessage(ctx, messageBOC)
}

// ─── Seed Phrase ────────────────────────────────────────────────

// GenerateSeedPhrase generates a 24-word BIP-39 style seed phrase.
func GenerateSeedPhrase() []string {
	const wordlist = "abandon ability able about above absent absorb abstract absurd abuse access accident account accuse achieve acid acoustic acquire across act action actor actress actual adapt add address adjust admit adopt advance advantage adventure affair afford afraid after again age agent agree ahead aim air airport alarm album alert alien align alive all allow almost alone along already also alter always amaze among amount ample anchor ancient angle animal ankle announce annual another answer antenna antique anxiety any apart apology appear apple approve april arch arctic area arena argue arm armor army around arrange arrest arrive arrow art aspect assault asset assist assume asthma athlete atom attack attend attitude attract auction audit august aunt author auto autumn average avocado avoid awake aware away awesome awful awkward axis baby bachelor bacon badge bag balance balcony ball bamboo banana banner bar barely bargain barrel base basic basket battle beach bean beauty because become beef before begin behave behind believe below belt bench benefit best better beyond bicycle bid bike bind biology bird birth bitter black blade blame blanket blast bleak bless blind blood blossom blouse blue blur blush board boat body boil bomb bone bonus book boost border boring borrow boss bottom bounce box boy bracket brain brand brass brave bread breeze brick bridge brief bright bring brisk broccoli broken bronze broom brother brown brush bubble buddy budget buffalo build bulb bulk bullet bundle bunker burden burger burst bus business busy butter buyer buzz cabbage cabin cable cactus cage cake call calm camera camp can canal cancel candle candy cannon canoe canvas canyon capable capital captain car carbon card cargo carpet carry cart case cash casino castle casual cat catalog catch category cattle caught cause caution cave ceiling celery cement census century cereal certain chair chalk champion change chaos chapter charge chase chat cheap check cheese chef cherry chest chicken chief child chimney choice choose chronic chuckle chunk churn cigar cinnamon circle citizen city civil claim clap clarify claw clay clean clerk clever click client cliff climb clinic clip clock clog close cloth cloud clown club clump cluster clutch coach coast coconut code coffee coil coin collect color column combine come comfort comic common company concert conduct confirm congress connect consider control convince cook cool copper copy coral core corn correct cost cotton couch country couple course cousin cover coyote crack cradle craft cram crane crash crater crawl crazy cream credit creek crew cricket crime crisp critic crop cross crouch crowd crucial cruel cruise crumble crunch crush cry crystal cube culture cup cupboard curious current curtain curve cushion custom cute cycle dad damage damp dance danger daring dash daughter dawn day deal debate debris decade december decide decline decorate decrease deer defense define defy degree delay deliver demand demise denial dentist deny depart depend deposit depth deputy derive describe desert design desk despair destroy detail detect develop device devote diagram dial diamond diary dice diesel diet differ digital dignity dilemma dinner dinosaur direct dirt disagree discover disease dish dismiss display distance divert divide divorce dizzy doctor document dog doll dolphin domain donate donkey donor door dose double dove draft dragon drama drastic draw dream dress drift drill drink drip drive drop drum dry duck dumb dune during dust dutch duty dwarf dynamic eager eagle early earn earth easily east easy echo ecology economy edge edit educate effort egg eight either elbow elder electric elegant element elephant elevator elite else embark embody embrace emerge emotion employ empower empty enable enact end endless endorse enemy energy enforce engage engine enhance enjoy enlist enough enrich enroll ensure enter entire entry envelope episode equal equip era erase erode erosion error erupt escape essay essence estate eternal ethics evidence evil evoke evolve exact example exceed excel except excerpt excite excuse execute exercise exhaust exhibit exile exist exit exotic expand expect expire explain expose express extend extra eye eyebrow fabric face faculty fade faint faith fall false fame family famous fan fancy fantasy farm fashion fat fatal father fatigue fault favorite feature february federal fee feed feel female fence festival fetch fever few fiber fiction field figure file film filter final find fine finger finish fire firm first fiscal fish fit fitness fix flag flame flash flat flavor flee flight flip float flock floor flower fluid flush fly foam focus fog foil fold follow food foot force foreign forest forget fork fortune forum forward fossil foster found fox fragile frame frequent fresh friend fringe frog front frost frown frozen fruit fuel fun funny furnace fury future gadget gain galaxy gallery game gap garage garbage garden garlic garment gas gasp gate gather gauge gaze general genius genre gentle genuine gesture ghost giant gift giggle ginger giraffe girl give glad glance glare glass glide glimpse globe gloom glory glove glow glue goat goddess gold good goose gorilla gospel gossip govern gown grab grace grain grant grape grass gravity great green grid grief grit grocery group grow grunt guard guess guide guilt guitar gun gym habit hair half hammer hamster hand happy harbor hard harsh harvest hat have hawk hazard head health heart heavy hedgehog height hello helmet help hen hero hidden high hill hint hip hire history hobby hockey hold hole holiday hollow home honey hood hope horn horror horse hospital host hotel hour hover hub huge human humble humor hundred hungry hunt hurdle hurry hurt husband hybrid ice icon idea identify idle ignore ill illegal illness image imitate immense immune impact impose improve impulse inch include income increase index indicate indoor industry infant inflict inform inhale inherit initial inject injury inmate inner innocent input inquiry insane insect inside inspire install intact interest into invest invite involve iron island isolate issue item ivory jacket jaguar jar jazz jealous jeans jelly jewel job join joke journey joy judge juice jump jungle junior junk just kangaroo keen keep ketchup key kick kid kidney kind kingdom kiss kit kitchen kite kitten kiwi knee knife knock know lab label labor ladder lady lake lamp language laptop large later latin laugh laundry lava law lawn lawsuit layer lazy leader leaf learn leave lecture left leg legal legend leisure lemon lend length lens leopard lesson letter level liar liberty library license life lift light like limb limit link lion liquid list little live lizard load loan lobster local lock logic lonely long loop lottery loud lounge love loyal lucky luggage lumber lunar lunch luxury lyrics machine mad magic magnet maid mail main major make mammal man manage mandate mango mansion manual maple marble march margin marine market marriage mask mass master match material math matrix matter maximum maze meadow mean measure meat mechanic medal media melody melt member memory mention menu mercy merge merit merry mesh message metal method middle midnight milk million mimic mind minimum minor minute miracle mirror misery miss mistake mix mixed mixture mobile model modify mom moment monitor monkey monster month moon moral more morning mosquito mother motion motor mountain mouse move movie much muffin mule multiply muscle museum mushroom music must mutual myself mystery myth naive name napkin narrow nasty nation nature near neck need negative neglect neither nephew nerve nest net network neutral never news next nice night noble noise nominee noodle normal north nose notable note nothing notice novel now nuclear number nurse nut oak obey object oblige obscure observe obtain obvious occur ocean october odor off offense offer office often oil okay old olive olympic omit once one onion online only open opera opinion oppose option orange orbit orchard order ordinary organ orient original orphan ostrich other outdoor outer output outside oval oven over own owner oxygen oyster ozone pact paddle page pair palace palm panda panel panic panther paper parade parent park parrot party pass patch path patient patrol pattern pause pave payment peace peanut pear peasant pelican pen penalty pencil people pepper perfect permit person pet phone photo phrase physical piano picnic picture piece pig pigeon pill pilot pink pioneer pipe pistol pitch pizza place planet plastic plate play player please pledge pluck plug plunge poem poet point polar pole police pond pony pool popular portion position possible post potato pottery poverty powder power practice praise predict prefer prepare present pretty prevent price pride primary print priority prison private prize problem process produce profit program project property proposal protect protein protest proud prove provide public pudding pull pulp pulse pumpkin punch pupil puppy purchase purity purpose purse push put puzzle pyramid quality quantum quarter question quick quit quiz quote rabbit raccoon race rack radar radio rail rain raise rally ramp ranch random range rapid rare rate rather raven raw razor ready real reason rebel rebuild recall receive recipe record recycle reduce reflect reform refuse region regret regular reject relax release relief rely remain remember remind remove render renew rent reopen repair repeat replace report require rescue resemble resist resource response result retire retreat return reunion reveal review reward rhythm rib ribbon rice rich ride ridge rifle right rigid ring riot rip ripe rise risk rival river road roast robot robust rocket romance roof rookie room rose rotate rough round route royal rubber rude rug rule run runway rural sad saddle sadness safe sail salad salmon salon salt salute same sample sand satisfy satoshi sauce sausage save say scale scan scare scatter scene scheme school science scissors scorpion scout scrap screen script scrub sea search season seat second secret section security seed seek segment select sell seminar senior sense sentence series service session settle setup seven shadow shaft shallow share shed shell sheriff shield shift shine ship shiver shock shoe shoot shop short shoulder shove shrimp shrug shuffle shy sibling sick side siege sight sign silent silk silly silver similar simple since sing siren sister situate six size skate sketch ski skill skin skirt skull slab slam sleep slender slice slide slight slim slogan slot slow slush small smart smile smoke smooth snack snake snap sniff snow soap soccer social sock soda soft solar soldier solid solution solve someone song soon sorry sort soul sound soup source south space spare spatial spawn speak special speed spell spend sphere spice spider spike spin spirit split spoil sponsor spoon sport spot spray spread spring spy square squeeze squirrel stable stadium staff stage stairs stamp stand start state stay steak steel steep steer stem step stereo stick still sting stock stomach stone stool story stove strategy street strike strong struggle student stuff stumble style subject submit subway success such sudden suffer sugar suggest suit sun sunny sunset super supply support suppose sure surface surge surprise surround survey suspect sustain swallow swamp swap swarm swear sweet swift swim swing switch sword symbol symptom syrup system table tackle tag tail talent talk tank tape target task taste tattoo taxi teach team tell ten tenant tennis tent term test text thank that theme then theory there they thing this thought three thrive throw thumb thunder ticket tide tiger tilt timber time tiny tip tired tissue title toast tobacco today toddler toe together toilet token tomato tomorrow tone tongue tonight tool tooth top topic topple torch tornado tortoise toss total tourist toward tower town toy track trade traffic tragic train transfer trap trash travel tray treat tree trend trial tribe trick trigger trim trip trophy trouble truck true truly trumpet trust truth try tube tuition tumble tuna tunnel turkey turn turtle twelve twenty twice twin twist two type typical ugly umbrella unable unaware uncle uncover under undo unfair unfold unhappy uniform unique unit universe unknown unlock until unusual unveil update upgrade uphold upon upper upset urban urge usage use used useful useless usual utility vacant vacuum vague valid valley valve van vanish vapor various vast vault vehicle velvet vendor venture venue verb verify version very vessel veteran viable vibrant vicious victory video view village vintage violin virtual virus visa visit visual vital vivid vocal voice void volcano volume vote voyage wage wagon wait walk wall walnut want warfare warm warrior wash wasp waste water wave way wealth weapon wear weasel weather web wedding weekend weird welcome west wet whale what wheat wheel when where whip whisper wide width wife wild will win window wine wing wink winner winter wire wisdom wise wish witness wolf woman wonder wood wool word work world worry worth wrap wreck wrestle wrist write wrong yard year yellow you young youth zebra zero zone zoo"
	words = strings.Fields(wordlist)
	seed   = make([]string, 24)
)

	for i := 0; i < 24; i++ {
		b := make([]byte, 2)
		rand.Read(b)
		idx := (int(b[0])<<8 | int(b[1])) % len(words)
		seed[i] = words[idx]
	}
	return seed
}

// ─── Internal ───────────────────────────────────────────────────

// graphQL performs a GraphQL request and decodes the response.
func (c *Client) graphQL(ctx context.Context, queryJSON string, result interface{}) error {
	body := strings.NewReader(queryJSON)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.graphqlURL, body)
	if err != nil {
		return fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("http call: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("read response: %w", err)
	}

	if err := json.Unmarshal(respBody, result); err != nil {
		return fmt.Errorf("parse response: %w", err)
	}

	return nil
}

// buildMockBOC creates a mock base64-encoded bag of cells for development.
// In production: use TVM SDK cell serialization.
func buildMockBOC(payload string, sig []byte) string {
	msg := map[string]interface{}{
		"payload":   payload,
		"signature": hex.EncodeToString(sig),
	}
	data, _ := json.Marshal(msg)
	return base64Encode(data)
}

func base64Encode(data []byte) string {
	return base64.StdEncoding.EncodeToString(data)
}
