defmodule DIA.Auth.Token do
  use Joken.Config

  @secret System.get_env("JWT_SECRET") ||
            "I2RnY7goIbQLT7sjV8ROSJlRSU-CDX3NPyZAy-IIWrxAe9U0rgPlBIpI7pDMWSRXFdjNH91_PwohKVBLT-fcDg"

  # Helper function to compute expiration time (Unix timestamp)
  # 1 hour
  @expiry_in_seconds 3600

  # Token configuration (no chat_id)
  @impl true
  def token_config do
    default_claims(skip: [:iss, :aud], default_expiry: @expiry_in_seconds)
    |> add_claim("user_id", nil, &(&1 != nil))
    |> add_claim("login_session_id", nil, &(&1 != nil))
  end

  def encode(claims) when is_map(claims) do
    # Ensure required fields have defaults
    enhanced_claims =
      claims
      |> Map.put_new("iat", DateTime.utc_now() |> DateTime.to_unix())

    Joken.generate_and_sign(
      token_config(),
      enhanced_claims,
      Joken.Signer.create("HS256", @secret)
    )
  end

  def decode(token),
    do: Joken.verify_and_validate(token_config(), token, Joken.Signer.create("HS256", @secret))

end
