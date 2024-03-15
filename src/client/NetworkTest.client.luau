--!strict

type AccountImpl = {
	__index: AccountImpl,
	new: (name: string, balance: number) -> Account,
	deposit: (self: Account, credit: number) -> (),
	withdraw: (self: Account, debit: number) -> (),
}

type Account = typeof(setmetatable({} :: { name: string, balance: number }, {} :: AccountImpl))

-- Only these two annotations are necessary
local Account: AccountImpl = {} :: AccountImpl
Account.__index = Account

-- Using the knowledge of `Account`, we can take in information of the `new` type from `AccountImpl`, so:
-- Account.new :: (name: string, balance: number) -> Account
function Account.new(name, balance)
	local self = {}
	self.name = name
	self.balance = balance

	return setmetatable(self, Account)
end

-- Ditto:
-- Account:deposit :: (self: Account, credit: number) -> ()
function Account:deposit(credit)
	self.balance += credit
end

-- Ditto:
-- Account:withdraw :: (self: Account, debit: number) -> ()
function Account:withdraw(debit)
	self.balance -= debit
end

local account = Account.new("Alexander", 500)
