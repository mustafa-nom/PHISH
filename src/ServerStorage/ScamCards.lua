--!strict
-- Scam card pool. Mirrors docs/PHISH_SCAM_CARDS.md (6 hand-written cards
-- + 4 quick stubs to fill the rotation; expand from the markdown to reach 20).
-- Server-only knowledge of `isLegit` — server is authoritative on the decision.

export type Link = { displayText: string, trueUrl: string }
export type Sender = { name: string, address: string, avatarColor: Color3 }
export type RedFlag = { element: string, reason: string }
export type Reward = { xp: number, coins: number }

export type ScamCard = {
	id: string,
	zone: string,
	isLegit: boolean,
	species: string,                  -- matches a PhishDex species id
	difficulty: number,               -- 1..5
	sender: Sender,
	subject: string,
	body: string,
	links: { Link },
	redFlags: { RedFlag },            -- empty if legit
	reward: Reward,
}

local ScamCards = {}

local C3 = Color3.fromRGB

ScamCards.All = {
	{
		id = "phish_urgency_001", zone = "InboxLake", isLegit = false,
		species = "UrgencyEel", difficulty = 1,
		sender = { name = "Netflix Billing", address = "netflix-acct@netfllx-billing.com", avatarColor = C3(229, 9, 20) },
		subject = "ACTION REQUIRED: Your account expires in 24 hours",
		body = "Hello,\n\nWe were unable to process your last payment. Your Netflix subscription will be CANCELLED in 24 hours unless you update your billing information immediately.\n\nThe Netflix Team",
		links = { { displayText = "UPDATE NOW", trueUrl = "http://netfllx-billing.com/restore" } },
		redFlags = {
			{ element = "sender.address", reason = "Domain \"netfllx\" instead of \"netflix\"" },
			{ element = "subject", reason = "Urgency language and time pressure" },
			{ element = "links[1]", reason = "Mismatched domain" },
		},
		reward = { xp = 15, coins = 5 },
	},
	{
		id = "legit_github_001", zone = "InboxLake", isLegit = true,
		species = "PlainCarp", difficulty = 1,
		sender = { name = "GitHub", address = "noreply@github.com", avatarColor = C3(36, 41, 47) },
		subject = "[GitHub] A new sign-in to your account",
		body = "Hi mus-the-builder,\n\nWe noticed a new sign-in to your GitHub account from Chrome on macOS in Los Angeles, CA, US.\n\nIf this was you, no action is needed.\nIf this wasn't you, please reset your password.\n\nThanks,\nThe GitHub Team",
		links = {},
		redFlags = {},
		reward = { xp = 10, coins = 3 },
	},
	{
		id = "phish_authority_001", zone = "InboxLake", isLegit = false,
		species = "AuthorityAnglerfish", difficulty = 2,
		sender = { name = "IRS Tax Department", address = "official@irs-gov-refund.org", avatarColor = C3(40, 60, 100) },
		subject = "Your tax refund of $1,847.00 is ready",
		body = "Dear Taxpayer,\n\nOur records indicate you are owed a refund of $1,847.00 from the previous tax year. To claim your refund, please verify your identity using the secure link below.\n\nFailure to verify within 5 business days will result in forfeiture of the refund.\n\nIRS Department of Revenue",
		links = { { displayText = "CLAIM REFUND", trueUrl = "https://irs-gov-refund.org/verify" } },
		redFlags = {
			{ element = "sender.address", reason = "IRS uses .gov, not .org" },
			{ element = "body", reason = "IRS does not contact taxpayers via email about refunds" },
			{ element = "subject", reason = "Authority impersonation + soft urgency" },
		},
		reward = { xp = 20, coins = 8 },
	},
	{
		id = "phish_reward_001", zone = "InboxLake", isLegit = false,
		species = "RewardTuna", difficulty = 1,
		sender = { name = "Apple Rewards", address = "prize-team@apple-rewards-claim.net", avatarColor = C3(160, 160, 160) },
		subject = "Congratulations! You've been selected for a free iPhone 15",
		body = "You have been randomly selected as our weekly winner!\n\nTo claim your free iPhone 15 Pro Max, please complete a short verification below. Hurry — only 3 winners per week.\n\n— The Apple Rewards Team",
		links = { { displayText = "CLAIM YOUR PRIZE", trueUrl = "https://apple-rewards-claim.net/winner/x73" } },
		redFlags = {
			{ element = "sender.address", reason = "Apple does not run \"rewards\" lotteries" },
			{ element = "body", reason = "Too-good-to-be-true reward, no entry was made" },
			{ element = "links[1]", reason = "Suspicious lookalike domain" },
		},
		reward = { xp = 15, coins = 5 },
	},
	{
		id = "phish_fear_001", zone = "InboxLake", isLegit = false,
		species = "FearBass", difficulty = 2,
		sender = { name = "Microsoft Account Team", address = "security-alert@ms-account-secure.com", avatarColor = C3(0, 120, 215) },
		subject = "Suspicious login detected — action required",
		body = "We detected a sign-in attempt to your Microsoft account from an unrecognized device in Lagos, Nigeria.\n\nIf this was not you, your account may be compromised. Click below to secure it now.\n\nIf you do not act within 24 hours, your account will be locked.",
		links = { { displayText = "SECURE MY ACCOUNT", trueUrl = "https://ms-account-secure.com/recover" } },
		redFlags = {
			{ element = "sender.address", reason = "Real sender is microsoft.com, not ms-account-secure" },
			{ element = "body", reason = "Fear-based geographic threat + urgency" },
			{ element = "links[1]", reason = "Lookalike domain" },
		},
		reward = { xp = 20, coins = 8 },
	},
	{
		id = "legit_bank_001", zone = "InboxLake", isLegit = true,
		species = "HonestHerring", difficulty = 1,
		sender = { name = "Chase", address = "no-reply@chase.com", avatarColor = C3(28, 84, 142) },
		subject = "Your monthly statement is ready",
		body = "Hi Alex,\n\nYour statement for account ending in 4291 is now available. View it any time by signing in directly at chase.com or in the Chase mobile app.\n\nWe never ask for your password by email.\n\nThank you for being a Chase customer.",
		links = {},
		redFlags = {},
		reward = { xp = 10, coins = 3 },
	},
	{
		id = "phish_curiosity_001", zone = "InboxLake", isLegit = false,
		species = "CuriosityCatfish", difficulty = 2,
		sender = { name = "Notification", address = "alerts@view-message-now.co", avatarColor = C3(140, 140, 140) },
		subject = "Is this you in this photo?",
		body = "Hey,\n\nSomeone tagged a photo of you. Click below to view before it's removed.",
		links = { { displayText = "View photo", trueUrl = "https://view-message-now.co/p/8121" } },
		redFlags = {
			{ element = "sender.address", reason = "Generic sender, suspicious .co domain" },
			{ element = "body", reason = "Vague clickbait with no personal context" },
			{ element = "links[1]", reason = "Lookalike domain" },
		},
		reward = { xp = 15, coins = 5 },
	},
	{
		id = "phish_familiarity_001", zone = "InboxLake", isLegit = false,
		species = "FamiliarityFlounder", difficulty = 2,
		sender = { name = "Mom", address = "mom.real.account@gmaiI.com", avatarColor = C3(220, 180, 200) },
		subject = "Quick favor",
		body = "Hey it's me — phone broke, can you grab two $100 Steam gift cards and send me the codes? I'll pay you back tonight. Don't call, I'm in a meeting.",
		links = {},
		redFlags = {
			{ element = "sender.address", reason = "Capital I instead of lowercase l in gmail" },
			{ element = "body", reason = "Out-of-character request + \"don't call me\"" },
		},
		reward = { xp = 20, coins = 8 },
	},
	{
		id = "legit_school_001", zone = "InboxLake", isLegit = true,
		species = "PlainCarp", difficulty = 1,
		sender = { name = "Roosevelt Middle School", address = "office@rms.k12.us", avatarColor = C3(120, 60, 80) },
		subject = "Parent-teacher night this Thursday",
		body = "Hello families,\n\nA reminder that parent-teacher night is this Thursday at 6:30pm in the gym. Sign up for your time slot through the parent portal.\n\nSee you there,\n— The RMS office",
		links = {},
		redFlags = {},
		reward = { xp = 10, coins = 3 },
	},
	{
		id = "legit_shipping_001", zone = "InboxLake", isLegit = true,
		species = "HonestHerring", difficulty = 1,
		sender = { name = "UPS", address = "tracking@ups.com", avatarColor = C3(115, 75, 30) },
		subject = "Your package has shipped",
		body = "Tracking #: 1Z999AA10123456784\nEstimated delivery: Friday by 8pm.\n\nYou can track this shipment any time by signing in to ups.com.",
		links = {},
		redFlags = {},
		reward = { xp = 10, coins = 3 },
	},
	{
		id = "phish_urgency_002", zone = "InboxLake", isLegit = false,
		species = "UrgencyEel", difficulty = 2,
		sender = { name = "Amazon Support", address = "delivery-issue@amaz0n-support.help", avatarColor = C3(255, 153, 0) },
		subject = "Delivery problem — confirm address in 12 hours",
		body = "Hi customer,\n\nWe were unable to deliver your recent order due to an address mismatch. Please reconfirm your shipping details within 12 hours or your package will be returned and a $4.99 fee applied.\n\n— Amazon Delivery Support",
		links = { { displayText = "Confirm address", trueUrl = "https://amaz0n-support.help/r/9281" } },
		redFlags = {
			{ element = "sender.address", reason = "\"amaz0n\" with a zero, on a .help TLD" },
			{ element = "subject", reason = "Tight time window manufactures urgency" },
			{ element = "links[1]", reason = "Lookalike domain on a non-standard TLD" },
		},
		reward = { xp = 20, coins = 8 },
	},
	{
		id = "phish_urgency_003", zone = "InboxLake", isLegit = false,
		species = "UrgencyEel", difficulty = 3,
		sender = { name = "Cloudflare DNS", address = "renewals@dns-renew-now.net", avatarColor = C3(244, 129, 32) },
		subject = "Your domain expires TODAY — auto-renew failed",
		body = "Auto-renewal for your domain failed (expired credit card on file). The domain will be released in 6 hours and your sites will go offline.\n\nRenew via the link below to keep ownership.",
		links = { { displayText = "Renew domain", trueUrl = "https://dns-renew-now.net/portal" } },
		redFlags = {
			{ element = "sender.address", reason = "Cloudflare uses cloudflare.com, never \"dns-renew-now.net\"" },
			{ element = "subject", reason = "Compressed deadline — \"TODAY\"" },
			{ element = "body", reason = "Real registrars send several reminders over weeks, not 6-hour panic" },
		},
		reward = { xp = 30, coins = 12 },
	},
	{
		id = "phish_authority_002", zone = "InboxLake", isLegit = false,
		species = "AuthorityAnglerfish", difficulty = 3,
		sender = { name = "FBI Cyber Division", address = "officer.barnes@fbi-cyber-watch.com", avatarColor = C3(20, 35, 80) },
		subject = "Federal warrant pending — contact officer Barnes",
		body = "This is an automated notice. Your IP address has been flagged in connection with an active investigation. Failure to contact Officer Barnes within 48 hours may result in a federal warrant being issued.\n\nReply to this address or call the number provided to schedule a clearance interview.",
		links = {},
		redFlags = {
			{ element = "sender.address", reason = "FBI uses fbi.gov, not \"fbi-cyber-watch.com\"" },
			{ element = "body", reason = "Real federal agencies don't issue warrants by email" },
			{ element = "subject", reason = "Authority impersonation + fear-based pressure" },
		},
		reward = { xp = 30, coins = 12 },
	},
	{
		id = "phish_authority_003", zone = "InboxLake", isLegit = false,
		species = "AuthorityAnglerfish", difficulty = 2,
		sender = { name = "Roblox Moderator", address = "review@roblox-moderation.app", avatarColor = C3(0, 162, 255) },
		subject = "Your account is under review",
		body = "Your Roblox account has been flagged for review. To avoid suspension, please verify ownership by signing in at the link below within 24 hours.\n\nFailure to respond will result in temporary suspension.\n\n— Roblox Moderation",
		links = { { displayText = "Verify ownership", trueUrl = "https://roblox-moderation.app/verify" } },
		redFlags = {
			{ element = "sender.address", reason = "Roblox staff never email from \"roblox-moderation.app\"" },
			{ element = "body", reason = "Real moderators don't ask you to log in via email" },
			{ element = "links[1]", reason = "Lookalike domain on the wrong TLD" },
		},
		reward = { xp = 20, coins = 8 },
	},
	{
		id = "phish_reward_002", zone = "InboxLake", isLegit = false,
		species = "RewardTuna", difficulty = 2,
		sender = { name = "Roblox Rewards", address = "winners@robux-bonus-claim.club", avatarColor = C3(0, 162, 255) },
		subject = "You earned 10,000 R$ for being our 1,000,000th visitor!",
		body = "Congratulations — you are this week's lucky visitor! Claim 10,000 free Robux by completing the verification step below.\n\nOnly 3 winners selected per week. Claim before this email expires.",
		links = { { displayText = "Claim 10,000 R$", trueUrl = "https://robux-bonus-claim.club/winner" } },
		redFlags = {
			{ element = "sender.address", reason = "Real Roblox payments don't come from \".club\" domains" },
			{ element = "body", reason = "Free Robux giveaways are always scams" },
			{ element = "links[1]", reason = "Suspicious lookalike domain" },
		},
		reward = { xp = 20, coins = 8 },
	},
	{
		id = "phish_curiosity_002", zone = "InboxLake", isLegit = false,
		species = "CuriosityCatfish", difficulty = 2,
		sender = { name = "Photo Tag Notice", address = "noreply@viewmedia-now.co", avatarColor = C3(140, 140, 140) },
		subject = "Is this you in this video?",
		body = "Someone shared a video that has you in it.\n\nPreview here before it goes private.",
		links = { { displayText = "View video", trueUrl = "https://viewmedia-now.co/v/4112" } },
		redFlags = {
			{ element = "sender.address", reason = "Generic sender on a .co domain — no platform brand" },
			{ element = "body", reason = "Vague clickbait — \"someone\" with no context" },
			{ element = "links[1]", reason = "Lookalike of legitimate media URLs" },
		},
		reward = { xp = 20, coins = 8 },
	},
	{
		id = "phish_fear_002", zone = "InboxLake", isLegit = false,
		species = "FearBass", difficulty = 3,
		sender = { name = "iCloud Security", address = "security@icloud-photo-recovery.com", avatarColor = C3(0, 122, 255) },
		subject = "Your iCloud photos were leaked — view album",
		body = "We detected an unauthorized download of photos from your iCloud account. To review what was leaked and revoke access, sign in at the secure link below.\n\nIf you do not act in 24 hours, the album will be made public.",
		links = { { displayText = "View leaked album", trueUrl = "https://icloud-photo-recovery.com/album" } },
		redFlags = {
			{ element = "sender.address", reason = "Apple uses apple.com / icloud.com, never \"icloud-photo-recovery.com\"" },
			{ element = "body", reason = "Apple does not threaten to publish a user's photos" },
			{ element = "subject", reason = "Fear bait designed to short-circuit thinking" },
		},
		reward = { xp = 30, coins = 12 },
	},
	{
		id = "phish_familiarity_002", zone = "InboxLake", isLegit = false,
		species = "FamiliarityFlounder", difficulty = 3,
		sender = { name = "Jordan", address = "jordan.real.94@gmaiI.com", avatarColor = C3(120, 200, 220) },
		subject = "weird favor",
		body = "ok this is gonna sound dumb but i'm stuck and can't call. can you grab two $100 Steam gift cards and text me the codes? I'll venmo you tomorrow morning, promise. don't tell my mom lol",
		links = {},
		redFlags = {
			{ element = "sender.address", reason = "Capital I instead of lowercase l in \"gmail\"" },
			{ element = "body", reason = "Out-of-character request: gift cards + can't call + secrecy" },
		},
		reward = { xp = 30, coins = 12 },
	},
	{
		id = "legit_recovery_001", zone = "InboxLake", isLegit = true,
		species = "HonestHerring", difficulty = 2,
		sender = { name = "GitHub", address = "noreply@github.com", avatarColor = C3(36, 41, 47) },
		subject = "[GitHub] Your authentication recovery codes",
		body = "Hi mus-the-builder,\n\nYou requested new recovery codes for two-factor authentication. The codes are attached to this email.\n\nKeep them somewhere safe — we won't be able to send them again. If you did not request this, please reset your password.\n\n— The GitHub Team",
		links = {},
		redFlags = {},
		reward = { xp = 14, coins = 4 },
	},
	{
		id = "legit_newsletter_001", zone = "InboxLake", isLegit = true,
		species = "PlainCarp", difficulty = 1,
		sender = { name = "Atlas Obscura", address = "newsletter@atlasobscura.com", avatarColor = C3(40, 80, 60) },
		subject = "Today's wonder: the moss spires of Patagonia",
		body = "Welcome to today's edition of Atlas Obscura. Featured this week: the moss spires of Torres del Paine, a 12-foot ice carving from a single block, and the world's smallest opera house.\n\nUnsubscribe at any time from your account preferences.",
		links = {},
		redFlags = {},
		reward = { xp = 10, coins = 3 },
	},
}

function ScamCards.PickForDifficulty(maxDifficulty: number): ScamCard
	local pool = {}
	for _, c in ipairs(ScamCards.All) do
		if c.difficulty <= maxDifficulty then table.insert(pool, c) end
	end
	if #pool == 0 then return ScamCards.All[1] end
	return pool[math.random(1, #pool)]
end

function ScamCards.GetById(id: string): ScamCard?
	for _, c in ipairs(ScamCards.All) do
		if c.id == id then return c end
	end
	return nil
end

return ScamCards
