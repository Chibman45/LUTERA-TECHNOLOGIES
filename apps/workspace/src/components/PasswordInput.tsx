"use client";
import { useId, useState, type InputHTMLAttributes } from "react";
import { passwordRules } from "@/lib/password";
export default function PasswordInput({
  label,
  requirements = false,
  ...props
}: Omit<InputHTMLAttributes<HTMLInputElement>, "type"> & {
  label: string;
  requirements?: boolean;
}) {
  const [visible, setVisible] = useState(false),
    [current, setCurrent] = useState("");
  const id = useId(),
    rulesId = id + "-rules";
  return (
    <div className="password-field">
      <label htmlFor={id}>{label}</label>
      <div className="password-control">
        <input
          {...props}
          id={id}
          type={visible ? "text" : "password"}
          aria-describedby={requirements ? rulesId : props["aria-describedby"]}
          onChange={(event) => {
            setCurrent(event.target.value);
            props.onChange?.(event);
          }}
        />
        <button
          type="button"
          className="password-eye"
          aria-label={`${visible ? "Hide" : "Show"} ${label.toLowerCase()}`}
          aria-pressed={visible}
          onClick={() => setVisible((v) => !v)}
        >
          <svg
            width="20"
            height="20"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.7"
            aria-hidden="true"
          >
            <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12Z" />
            <circle cx="12" cy="12" r="3" />
            {visible && <path d="m3 3 18 18" />}
          </svg>
        </button>
      </div>
      {requirements && (
        <ul
          className="password-rules"
          id={rulesId}
          aria-label="Password requirements"
        >
          {passwordRules.map((rule) => (
            <li key={rule.id} className={rule.test(current) ? "met" : ""}>
              <span aria-hidden="true">{rule.test(current) ? "✓" : "○"}</span>{" "}
              {rule.label}
              <span className="sr-only">
                {rule.test(current) ? ", met" : ", not met"}
              </span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
